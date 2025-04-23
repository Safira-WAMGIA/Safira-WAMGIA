"""Custom transformer implementation for fallback."""
import torch
import torch.nn as nn
import math
import logging

# Set up logging
logger = logging.getLogger(__name__)

class RMSNorm(nn.Module):
    """Root Mean Square Layer Normalization."""
    
    def __init__(self, dim: int, eps: float = 1e-6):
        super().__init__()
        self.eps = eps
        self.weight = nn.Parameter(torch.ones(dim))

    def forward(self, x):
        # Calculate RMS
        rms = torch.rsqrt(x.pow(2).mean(-1, keepdim=True) + self.eps)
        return self.weight * rms * x


class RotaryEmbedding(nn.Module):
    """Rotary positional embedding."""
    
    def __init__(self, dim, max_seq_len=2048, base=10000):
        super().__init__()
        self.dim = dim
        self.max_seq_len = max_seq_len
        self.base = base
        
        # Generate frequency tensor
        inv_freq = 1.0 / (base ** (torch.arange(0, dim, 2).float() / dim))
        self.register_buffer("inv_freq", inv_freq)
        
        # Generate cos and sin cache
        self._update_cos_sin_cache(max_seq_len)
        
    def _update_cos_sin_cache(self, max_seq_len):
        """Update the cache of cos and sin values."""
        self.max_seq_len = max_seq_len
        t = torch.arange(max_seq_len, device=self.inv_freq.device)
        
        # Compute cos and sin at each position
        freqs = torch.einsum('i,j->ij', t, self.inv_freq)
        cos = freqs.cos()
        sin = freqs.sin()
        
        self.register_buffer("cos_cache", cos, persistent=False)
        self.register_buffer("sin_cache", sin, persistent=False)
        
    def forward(self, x, seq_len=None, pos=None):
        # Get appropriate parts of the cache
        if pos is not None:
            # Handle arbitrary positions
            cos = self.cos_cache[pos]
            sin = self.sin_cache[pos]
        else:
            # Handle sequential positions
            seq_len = x.shape[1] if seq_len is None else seq_len
            cos = self.cos_cache[:seq_len]
            sin = self.sin_cache[:seq_len]
            
        return cos, sin


def rotate_half(x):
    """Rotate half the dimensions of the input."""
    x1, x2 = x.chunk(2, dim=-1)
    return torch.cat((-x2, x1), dim=-1)


def apply_rotary_pos_emb(q, k, cos, sin, position_ids=None):
    """Apply rotary position embedding to q and k."""
    if position_ids is not None:
        # Handle arbitrary positions
        cos = cos[position_ids].unsqueeze(1)  # [bs, 1, seq_len, dim]
        sin = sin[position_ids].unsqueeze(1)  # [bs, 1, seq_len, dim]
    else:
        # Handle sequential positions
        cos = cos.unsqueeze(0).unsqueeze(0)  # [1, 1, seq_len, dim]
        sin = sin.unsqueeze(0).unsqueeze(0)  # [1, 1, seq_len, dim]
    
    # Apply rotation
    q_embed = (q * cos) + (rotate_half(q) * sin)
    k_embed = (k * cos) + (rotate_half(k) * sin)
    
    return q_embed, k_embed


class CustomAttention(nn.Module):
    """Multi-head attention with support for KV caching."""
    
    def __init__(self, dim, num_heads, num_kv_heads=None, dropout=0.0):
        super().__init__()
        self.dim = dim
        self.num_heads = num_heads
        self.num_kv_heads = num_kv_heads or num_heads
        self.head_dim = dim // num_heads
        self.scale = self.head_dim ** -0.5
        
        # Attention projections
        self.q_proj = nn.Linear(dim, num_heads * self.head_dim, bias=False)
        self.k_proj = nn.Linear(dim, self.num_kv_heads * self.head_dim, bias=False)
        self.v_proj = nn.Linear(dim, self.num_kv_heads * self.head_dim, bias=False)
        self.o_proj = nn.Linear(num_heads * self.head_dim, dim, bias=False)
        
        # Rotary embedding
        self.rope = RotaryEmbedding(self.head_dim)
        
        # Dropout
        self.dropout = nn.Dropout(dropout)
        
    def _repeat_kv(self, x):
        """Repeat KV heads to match the number of query heads."""
        if self.num_kv_heads == self.num_heads:
            return x
        
        b, s, n_kv_head, head_dim = x.shape
        
        # Repeat the KV heads to match the number of query heads
        repeats = self.num_heads // self.num_kv_heads
        x = x.repeat_interleave(repeats, dim=2)
        
        return x
        
    def forward(self, x, mask=None, input_pos=None, kv_cache=None):
        batch_size, seq_len, _ = x.shape
        
        # Project to q, k, v
        q = self.q_proj(x).view(batch_size, seq_len, self.num_heads, self.head_dim).transpose(1, 2)  # [b, nh, s, hd]
        k = self.k_proj(x).view(batch_size, seq_len, self.num_kv_heads, self.head_dim).transpose(1, 2)  # [b, nkh, s, hd]
        v = self.v_proj(x).view(batch_size, seq_len, self.num_kv_heads, self.head_dim).transpose(1, 2)  # [b, nkh, s, hd]
        
        # Apply rotary embeddings
        cos, sin = self.rope.forward(x, seq_len=seq_len, pos=input_pos)
        q, k = apply_rotary_pos_emb(q, k, cos, sin, position_ids=input_pos)
        
        # Handle KV cache
        if kv_cache is not None:
            k_cache, v_cache = kv_cache
            
            if input_pos is not None:
                # Update cache at specific positions
                k_cache.index_copy_(2, input_pos, k)
                v_cache.index_copy_(2, input_pos, v)
                
                # Use the entire cache
                k, v = k_cache, v_cache
        
        # Repeat KV if needed
        k = self._repeat_kv(k)
        v = self._repeat_kv(v)
        
        # Calculate attention scores
        attention_scores = torch.matmul(q, k.transpose(-2, -1)) * self.scale
        
        # Apply mask if provided
        if mask is not None:
            attention_scores = attention_scores.masked_fill(mask == 0, -10000.0)
            
        # Apply softmax and dropout
        attention_probs = self.dropout(torch.softmax(attention_scores, dim=-1))
        
        # Get context vector
        context = torch.matmul(attention_probs, v)
        
        # Reshape and project back
        context = context.transpose(1, 2).contiguous().view(batch_size, seq_len, -1)
        output = self.o_proj(context)
        
        return output


class FeedForward(nn.Module):
    """Feed-forward network with GELU activation."""
    
    def __init__(self, dim, hidden_dim, dropout=0.0):
        super().__init__()
        self.w1 = nn.Linear(dim, hidden_dim, bias=False)
        self.w2 = nn.Linear(hidden_dim, dim, bias=False)
        self.dropout = nn.Dropout(dropout)
        self.act = nn.GELU()
        
    def forward(self, x):
        x = self.w1(x)
        x = self.act(x)
        x = self.dropout(x)
        x = self.w2(x)
        return x


class TransformerLayer(nn.Module):
    """A single transformer layer."""
    
    def __init__(
        self, 
        dim, 
        num_heads, 
        num_kv_heads=None,
        ffn_dim=None, 
        dropout=0.0, 
        norm_eps=1e-5
    ):
        super().__init__()
        self.norm1 = RMSNorm(dim, eps=norm_eps)
        self.attn = CustomAttention(dim, num_heads, num_kv_heads, dropout)
        self.norm2 = RMSNorm(dim, eps=norm_eps)
        self.ffn = FeedForward(
            dim, 
            ffn_dim or 4 * dim, 
            dropout
        )
        
    def forward(self, x, mask=None, input_pos=None, kv_cache=None):
        # Self-attention with residual
        h = self.norm1(x)
        h = self.attn(h, mask=mask, input_pos=input_pos, kv_cache=kv_cache)
        x = x + h
        
        # FFN with residual
        h = self.norm2(x)
        h = self.ffn(h)
        x = x + h
        
        return x


class CustomTransformerDecoder(nn.Module):
    """Custom transformer decoder that mimics Llama architecture."""
    
    def __init__(
        self,
        vocab_size,
        num_layers,
        num_heads,
        num_kv_heads,
        embed_dim,
        max_seq_len,
        intermediate_dim,
        attn_dropout=0.0,
        norm_eps=1e-5,
        rope_base=10000,
    ):
        super().__init__()
        self.vocab_size = vocab_size
        self.max_seq_len = max_seq_len
        self.embed_dim = embed_dim
        
        # Token embeddings
        self.tok_embeddings = nn.Embedding(vocab_size, embed_dim)
        
        # Transformer layers
        self.layers = nn.ModuleList([
            TransformerLayer(
                embed_dim,
                num_heads,
                num_kv_heads,
                intermediate_dim,
                attn_dropout,
                norm_eps
            )
            for _ in range(num_layers)
        ])
        
        # Final normalization and output projection
        self.norm = RMSNorm(embed_dim, eps=norm_eps)
        self.output = nn.Linear(embed_dim, vocab_size, bias=False)
        
        # Initialize the KV cache
        self._kv_cache = None
        self._has_cache = False
        
        logger.info(f"Initialized CustomTransformerDecoder with {num_layers} layers, {num_heads} heads, {embed_dim} dim")
        
    def setup_caches(self, batch_size, dtype, decoder_max_seq_len=None):
        """Set up KV caches for inference."""
        max_seq_len = decoder_max_seq_len or self.max_seq_len
        device = next(self.parameters()).device
        
        self._kv_cache = []
        for i, layer in enumerate(self.layers):
            # Create a KV cache for each layer
            k_cache = torch.zeros(
                batch_size,
                layer.attn.num_kv_heads,
                max_seq_len,
                layer.attn.head_dim,
                device=device,
                dtype=dtype
            )
            v_cache = torch.zeros(
                batch_size,
                layer.attn.num_kv_heads,
                max_seq_len,
                layer.attn.head_dim,
                device=device,
                dtype=dtype
            )
            self._kv_cache.append((k_cache, v_cache))
        
        self._has_cache = True
        logger.info(f"KV caches set up for {batch_size} batches, {max_seq_len} seq length")
        
    def caches_are_enabled(self):
        """Check if caches are enabled."""
        return self._has_cache
        
    def reset_caches(self):
        """Reset the KV cache to zeros."""
        if self._has_cache and self._kv_cache:
            for k_cache, v_cache in self._kv_cache:
                k_cache.zero_()
                v_cache.zero_()
    
    def forward(self, x, mask=None, input_pos=None):
        batch_size, seq_len = x.shape[:2]
        
        # Apply embedding if input is token IDs
        if x.dim() == 2:
            x = self.tok_embeddings(x)
        
        # Apply transformer layers
        for i, layer in enumerate(self.layers):
            layer_cache = self._kv_cache[i] if self._has_cache else None
            x = layer(x, mask=mask, input_pos=input_pos, kv_cache=layer_cache)
        
        # Apply final norm
        x = self.norm(x)
        
        # Skip output projection if using Identity
        if isinstance(self.output, nn.Identity):
            return x
        
        # Apply output projection
        logits = self.output(x)
        
        return logits
