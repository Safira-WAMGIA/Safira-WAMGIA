# 🧪 Testes Automatizados – Projeto Safira

Este diretório contém os testes automatizados da arquitetura modular do projeto Safira. Os testes são organizados por responsabilidade técnica e visam garantir qualidade, estabilidade e confiança em cada componente da aplicação.

---

## 📁 Estrutura

```
tests/
├── conftest.py                          # Configurações globais do Pytest
├── test_safira_core.py                 # Testes da lógica central de orquestração
├── test_api_venom.py                   # Testes da API do Venom (envio/recebimento de mensagens)
├── test_n8n_webhooks.py                # Valida fluxos disparados por webhooks do n8n
├── test_stt_pipeline.py                # Testa o pipeline de áudio para texto (STT)
├── test_tts_pipeline.py                # Testa o pipeline de texto para áudio (TTS)
├── test_image_reader.py                # Valida extração de texto de imagens (OCR)
├── test_payment_flow.py                # Simula e valida o fluxo de pagamento por PIX
├── test_ai_functions.py                # Testa chamadas e resposta dos agentes de IA
├── test_integrations/
│   ├── test_postgres.py                # Testa conexão e queries com banco PostgreSQL
│   ├── test_redis.py                   # Testa caching e leitura/escrita no Redis
│   └── test_grafana_prom.py           # Valida exposição de métricas Prometheus/Grafana
└── mocks/
    ├── fake_message.json              # Mock de mensagem de entrada do WhatsApp
    └── fake_audio.wav                 # Mock de áudio para teste do STT
```

---

## 🧠 Descrição dos Testes

### `test_safira_core.py`
Verifica se a orquestração principal dos agentes está funcionando corretamente. Ideal para testar memória contextual, roteamento interno e fluxo principal de decisão.

### `test_api_venom.py`
Testa endpoints da API local usada para integração WhatsApp via Venom. Verifica envio, recebimento, status e fallback de mensagens.

### `test_n8n_webhooks.py`
Simula triggers do n8n via chamadas HTTP. Ideal para validar se os workflows corretos são iniciados com os dados esperados.

### `test_stt_pipeline.py` & `test_tts_pipeline.py`
Verificam o processamento de áudio: entrada de voz → texto e texto → geração de áudio. Simulam uso real com mocks de áudio.

### `test_image_reader.py`
Valida extração de dados via OCR de imagens enviadas ao sistema, garantindo a leitura de texto mesmo em imagens com ruído.

### `test_payment_flow.py`
Testa a lógica de geração, recebimento e verificação de pagamentos via PIX. Simula respostas do gateway e webhooks.

### `test_ai_functions.py`
Valida as chamadas ao container `ai-functions`, checando consistência das entradas e saídas dos modelos PydanticAI ou LLMs locais.

### `test_integrations/`
Conjunto de testes que verifica integração com serviços essenciais:
- PostgreSQL
- Redis
- Prometheus / Grafana

### `mocks/`
Contém dados simulados usados nos testes automatizados, como mensagens JSON e áudios falsos.

---

## ▶️ Rodando os testes

Você pode executar todos os testes com:

```bash
pytest -q tests/
```

Ou rodar arquivos isolados:

```bash
pytest tests/test_api_venom.py
```

Recomendamos criar um ambiente virtual e instalar as dependências de desenvolvimento via `requirements-dev.txt`.

---

## 💎 Manter qualidade é parte da missão da Safira.
