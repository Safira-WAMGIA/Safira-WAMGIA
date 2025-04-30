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
  browserArgs: ['--no-sandbox'],
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
        try {
          console.log('📤 Enviando áudio com: sendFileFromBase64');
          console.log('➡️ To:', to);
          console.log('➡️ Mimetype:', file?.mimetype);
          console.log('➡️ Filename:', file?.filename);
          console.log('➡️ Base64 (primeiros 50):', file?.data?.slice(0, 50));
      
          await venomClient.sendFileFromBase64(
            to,
            file?.data,
            file?.filename || 'audio.ogg',
            '',
            file?.mimetype || 'audio/ogg'
          );
      
          console.log('✅ Enviado com sucesso!');
        } catch (err) {
          console.error('❌ Erro ao enviar áudio:', err);
        }
        break;
        
        

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
