import { create } from 'venom-bot';
import axios from 'axios';
import express from 'express';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

dotenv.config();

const WEBHOOK_URL = process.env.WEBHOOK_URL?.trim();
const PORT = process.env.PORT || 3000;

if (!WEBHOOK_URL) {
  console.error('❌ Variável de ambiente WEBHOOK_URL não definida!');
  process.exit(1);
}

// ───────────────────────────── Express Health‑check ─────────────────────────────
const app = express();
app.get('/status', (_, res) => res.json({ status: 'ok', service: 'safira-whatsapp-bridge' }));
app.listen(3000, () => console.log('🌐  HTTP server on :3000 (/status)'));

// Pasta temporária para qualquer download de mídia
const TMP_DIR = path.resolve('./tmp');
if (!fs.existsSync(TMP_DIR)) fs.mkdirSync(TMP_DIR);

// ─────────────────────────── Venom client init ─────────────────────────────────
create({
  session: 'safira-session',
  multidevice: true,
  disableWelcome: true,
  headless: true,
  browserArgs: ['--no-sandbox'],
  mkdirFolderToken: './tokens'
}).then((client) => {
  console.log('🤖 Venom inicializado, aguardando mensagens…');

  client.onMessage(async (message) => {
    try {
      const payload = {
        type: message.type,           // chat, image, audio, ptt, video, doc, …
        body: message.body ?? '',
        from: message.from,
        to: message.to,
        isGroupMsg: message.isGroupMsg,
        mimetype: message.mimetype ?? null,
        caption: message.caption ?? null,
      };

      // Detecta mídia e faz download se necessário
      const hasMedia = !!message.mimetype && (message.isMedia || message.isMMS || message.type !== 'chat');
      if (hasMedia) {
        const buffer = await client.decryptFile(message); // Buffer
        const ext = message.mimetype.split('/')[1] || 'bin';
        const filename = `file_${Date.now()}.${ext}`;
        const filePath = path.join(TMP_DIR, filename);

        fs.writeFileSync(filePath, buffer);

        payload.file = {
          filename,
          mimetype: message.mimetype,
          data: buffer.toString('base64'), // Inline base64 (evita multipart no n8n)
        };

        // Limpeza opcional
        fs.unlink(filePath, () => {});
      }

      await axios.post(WEBHOOK_URL, payload, { timeout: 10000 });
      console.log('➡️  Evento enviado ao n8n:', WEBHOOK_URL);
    } catch (err) {
      console.error('🚨  Erro ao processar/enviar mensagem:', err.message);
    }
  });

}).catch((err) => {
  console.error('❌  Falha ao iniciar Venom:', err);
  process.exit(1);
});

app.listen(3000, () => {
  console.log('Server listening on port 3000');
});