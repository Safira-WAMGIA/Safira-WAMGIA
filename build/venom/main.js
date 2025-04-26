import { create } from 'venom-bot';
import axios from 'axios';
import dotenv from 'dotenv';

dotenv.config();

const WEBHOOK_URL = process.env.WEBHOOK_URL;

if (!WEBHOOK_URL) {
  console.error('⚠️  Variável de ambiente WEBHOOK_URL não definida!');
  process.exit(1);
}

create().then((client) => {
  client.onMessage(async (message) => {
    console.log('📩 Mensagem recebida:', message);

    try {
      await axios.post(WEBHOOK_URL, {
        type: message.type,          // text, image, audio, etc.
        body: message.body,          // texto da mensagem (se aplicável)
        from: message.from,          // número de quem enviou
        to: message.to,              // número que recebeu (nosso)
        isGroupMsg: message.isGroupMsg,
        mimetype: message.mimetype,  // tipo do arquivo (image/jpeg, audio/ogg etc)
        caption: message.caption,    // legenda (para imagem, vídeo)
        fileUrl: message.mediaKey    // 🔥 opcional: podemos expandir para pegar o arquivo depois
      });
      console.log('✅ Mensagem enviada para webhook.');
    } catch (error) {
      console.error('❌ Erro ao enviar para o webhook:', error.message);
    }
  });
});
