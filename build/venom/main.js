import { create } from 'venom-bot';
import axios from 'axios';
import express from 'express';
import dotenv from 'dotenv';
import fs from 'fs';
import path from 'path';

dotenv.config();

const TEST_MODE = 'true';
const OUT_WEBHOOK_URL = 'http://safira-core:5678/webhook-test/whatsapp-input';
const PORT = process.env.PORT || 3000;

console.log(`↗️  Enviando entradas para ${OUT_WEBHOOK_URL}`);
console.log(`🛂  Aguardando comandos POST em http://whatsapp:${PORT}/send`);

const app = express();
app.use(express.json({ limit: '25mb' }));
app.get('/status', (_, res) => res.json({ status: 'ok', testMode: TEST_MODE }));

const TMP_DIR = path.resolve('./tmp');
if (!fs.existsSync(TMP_DIR)) fs.mkdirSync(TMP_DIR);

let venomClient = null;
create({
  session: 'safira-session',
  multidevice: true,
  disableWelcome: true,
  headless: true,
  browserArgs: ['--no-sandbox', '--disable-dev-shm-usage'], // --disable-dev-shm-usage is good for Docker
  folderNameToken: 'tokens',
  mkdirFolderToken: '.',
  
}).then((client) => {
  venomClient = client;
  console.log('🤖 Venom pronto.');

  client.onMessage(async (msg) => {
    try {
      const payload = {
        type: msg.type,
        body: msg.body ?? '',
        from: msg.from,
        to: msg.to,
        isGroupMsg: msg.isGroupMsg,
        mimetype: msg.mimetype ?? null,
        caption: msg.caption ?? null,
      };
      if (msg.mimetype && (msg.isMedia || msg.isMMS || msg.type !== 'chat')) {
        const buf = await client.decryptFile(msg);
        payload.file = {
          filename: `file_${Date.now()}.${msg.mimetype.split('/')[1] || 'bin'}`,
          mimetype: msg.mimetype,
          data: buf.toString('base64'),
        };
      }
      await axios.post(OUT_WEBHOOK_URL, payload, { timeout: 10000 });
    } catch (e) {
      console.error('🚨  Falha ao notificar n8n:', e.message);
    }
  });

}).catch((err) => {
  console.error('❌  Não foi possível iniciar Venom:', err);
  process.exit(1);
});

app.post('/send', async (req, res) => {
  if (!venomClient) return res.status(503).json({ error: 'Venom não inicializado' });

  const { to, type = 'text', body = '', caption = '', file } = req.body || {};
  if (!to) return res.status(400).json({ error: 'Campo "to" é obrigatório' });

  try {
    switch (type) {
      case 'text':
        await venomClient.sendText(to, body);
        break;

      case 'image':
        await venomClient.sendImageFromBase64(to, file?.data, file?.filename || 'image.jpg', caption);
        break;

        case 'audio':
    console.log(`Processando 'case audio' para: ${to}`);
    try {
        // --- Validação Inicial ---
        if (!to) {
            console.error('Erro: Destinatário (to) não fornecido.');
            break; // Sai do case se não houver destinatário
        }
        if (!file || typeof file !== 'object') {
            console.error('Erro: Objeto "file" ausente ou inválido.');
            break; // Sai do case se o objeto file não existir
        }
        if (typeof file.data !== 'string' || file.data.trim().length === 0) {
            console.error('Erro: "file.data" (string Base64) está ausente, não é uma string ou está vazia.');
            break; // Sai do case se a base64 estiver faltando ou for inválida
        }

        console.log(' Dados recebidos:', {
            to: to,
            filenameOriginal: file.filename,
            mimetypeOriginal: file.mimetype,
            base64LengthOriginal: file.data.length,
            base64StartOriginal: file.data.slice(0, 50) + '...'
        });

        // --- Preparação da Base64 ---
        let base64Data = file.data;
        const dataUriPrefixRegex = /^data:[^;]+;base64,/; // Regex para detectar o prefixo "data:mime/type;base64,"

        // 1. Remover o Prefixo Data URI (se existir)
        if (dataUriPrefixRegex.test(base64Data)) {
            console.log('Prefixo Data URI detectado. Removendo...');
            base64Data = base64Data.replace(dataUriPrefixRegex, '');
            console.log('Prefixo removido. Novo tamanho:', base64Data.length);
            console.log('Base64 (início, após remover prefixo):', base64Data.slice(0, 50) + '...');
        } else {
            console.log('Nenhum prefixo Data URI detectado.');
        }

        // 2. Verificar se a string não ficou vazia após a remoção
        if (base64Data.trim().length === 0) {
            console.error('Erro: A string Base64 ficou vazia após o processamento.');
            break; // Sai se a string ficou vazia
        }

        // 3. (Opcional, mas recomendado) Validar a Base64 antes de enviar
        //    Isso ajuda a pegar erros de corrupção ANTES de chamar a API do WhatsApp
        try {
            // No Node.js, Buffer.from lança erro se a base64 for inválida
            Buffer.from(base64Data, 'base64');
            console.log('Validação básica da Base64 (tentativa de decodificação) bem-sucedida.');
        } catch (validationError) {
            console.error('------------------------------------------------------------');
            console.error('ERRO CRÍTICO: A string Base64 fornecida é INVÁLIDA!');
            console.error('Mensagem do erro de validação:', validationError.message);
            console.error('Base64 (início, inválida):', base64Data.slice(0, 100) + '...');
            console.error('Verifique a origem desta string Base64.');
            console.error('------------------------------------------------------------');
            break; // Sai do case pois a Base64 está corrompida
        }

        // --- Preparação dos Outros Parâmetros ---
        // Define valores padrão usando o operador de coalescência nula (??)
        const filenameToSend = file.filename ?? 'audio_enviado.ogg';
        // Usar um mimetype padrão razoável se não for fornecido
        const mimeTypeToSend = file.mimetype ?? 'audio/ogg; codecs=opus';

        console.log('--- Parâmetros Finais para Envio ---');
        console.log('Destinatário (to):', to);
        console.log('Filename:', filenameToSend);
        console.log('Mimetype:', mimeTypeToSend);
        console.log('Tamanho Base64 Final:', base64Data.length);
        console.log('Base64 Final (início):', base64Data.slice(0, 50) + '...');
        console.log('------------------------------------');

        // --- Envio ---
        console.log('Chamando venomClient.sendFileFromBase64...');
        await venomClient.sendFileFromBase64(
            to,
            base64Data,         // A string base64 LIMPA e validada
            filenameToSend,     // Nome do arquivo (com fallback)
            '',                 // Legenda (caption) - vazia para áudio
            mimeTypeToSend      // Mimetype (com fallback) - Importante!
        );

        console.log(`Áudio enviado com sucesso para ${to}!`);

    } catch (err) {
        console.error(`------------------------------------------------------------`);
        console.error(`ERRO GERAL ao tentar processar/enviar o áudio para ${to}:`);
        console.error('Mensagem:', err.message);
        console.error('Stack Trace (se disponível):', err.stack);
        // Logar o erro completo pode ajudar
        console.error('Objeto de Erro Completo:', err);
        console.error(`------------------------------------------------------------`);
        // Considere adicionar tratamento de erro mais específico aqui
        // Por exemplo, verificar se err.message contém "invalid media data" ou algo similar
    }
    break; // Fim do case 'audio'
        
        

      case 'video':
        await venomClient.sendVideoAsGifFromBase64(to, file?.data, file?.filename || 'video.mp4', caption);
        break;

      default:
        await venomClient.sendFileFromBase64(to, file?.data, file?.filename || 'file.bin', caption);
    }
    res.json({ status: 'sent' });
  } catch (e) {
    console.error('🚨  Erro ao enviar msg:', e.message);
    res.status(500).json({ error: e.message });
  }
});

app.listen(PORT, () => console.log(`🌐  HTTP server on :${PORT}`));
