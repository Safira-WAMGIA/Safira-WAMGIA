const { create } = require('venom-bot');

create().then((client) => {
  client.onMessage((message) => {
    console.log('Mensagem recebida:', message.body);
    if (message.body && message.isGroupMsg === false) {
      client.sendText(message.from, 'Olá! Aqui é a Safira ✨');
    }
  });
});
