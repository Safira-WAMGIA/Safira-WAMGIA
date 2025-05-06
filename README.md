# 🔷 Safira WAMGIA ![CI Status](https://img.shields.io/badge/build-pending-lightgrey)



![Versão](https://img.shields.io/badge/Versão-2025.04‑rev‑stable-blue?style=flat-square)
![Licença](https://img.shields.io/badge/Licença-Particular-red?style=flat-square)
![Ambiente](https://img.shields.io/badge/Ambiente-Docker%20Compose-blueviolet?style=flat-square)
![Infra](https://img.shields.io/badge/Infraestrutura-Microsserviços-orange?style=flat-square)

![Docker](https://img.shields.io/badge/Docker-24.x-2496ED?logo=docker&logoColor=white&style=flat-square)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white&style=flat-square)
![FastAPI](https://img.shields.io/badge/FastAPI-0.110-009688?logo=fastapi&logoColor=white&style=flat-square)
![n8n](https://img.shields.io/badge/n8n-Core-E85255?logo=n8n&logoColor=white&style=flat-square)
![WhatsApp](https://img.shields.io/badge/WhatsApp-Venom‑bot-25D366?logo=whatsapp&logoColor=white&style=flat-square)

## 🧠 Visão Geral

**Safira WAMGIA** é uma assistente pessoal automatizada, baseada em inteligência artificial e orquestração de workflows via **n8n**, executada 100% localmente por meio de containers Docker. A sigla **WAMGIA** significa "WhatsApp Assistant Modular com Gestão Inteligente e Autônoma", refletindo o conceito por trás da Safira: um núcleo de automação que interage com humanos de forma **multimodal** (texto, voz e imagem), com **respostas contextualizadas**, **análise emocional**, **privacidade garantida** e **expansão infinita por agentes especializados**.

### 🌟 O que a Safira faz
- Recebe mensagens via WhatsApp e outros canais (futuramente Telegram, Instagram, etc.)
- Compreende o conteúdo da mensagem (texto, imagem ou voz)
- Processa a intenção e o contexto usando modelos LLM locais (Ollama)
- Executa fluxos n8n com lógica personalizada para cada caso
- Retorna uma resposta inteligente em **texto**, **áudio** ou **imagem**
- Aprende com as interações e pode manter contexto, histórico e preferências do usuário

Um usuário envia um áudio no WhatsApp: "Me lembra de pagar o aluguel amanhã".

1. A mensagem é recebida pelo container `whatsapp` (Venom) e enviada ao `safira-core` (n8n).
2. O áudio é encaminhado ao serviço `whisper`, que transcreve para texto: "Me lembra de pagar o aluguel amanhã".
3. A frase transcrita é enviada para o agente `Safira`, que interpreta e reconhece a intenção: criar um lembrete.
4. O agente responde: "Pode deixar! Te lembro amanhã às 9h. 😉"
5. A resposta é enviada por texto ou áudio (via `tts`) de volta ao usuário via WhatsApp.

### 🧩 Exemplo prático de uso
Veja como a Safira pode atuar em diferentes contextos do dia a dia, de forma inteligente, sensível ao contexto e com respostas naturais:

#### 🗞️ De manhã cedo:
- O usuário envia um áudio: "Safira, me conta quais as notícias pra agora de manhã."
- A Safira transcreve o áudio, detecta o horário e o tom da solicitação, consulta fontes locais e entrega as principais manchetes de forma personalizada
- Como já conhece o usuário e sabe que ele é programador, prioriza notícias de tecnologia, IA e negócios digitais

#### 📅 Na parte da tarde:
- O usuário envia: "Marca uma reunião com o Fulano pra essa semana, o quanto antes."
- Safira entende a urgência e o tom direto, cruza os horários da agenda com os de Fulano e já sugere slots prontos para envio

#### 🐶 Situações inesperadas:
- O usuário manda: "Meu cachorro comeu duas bolachas, o que eu faço?"
- Safira entende que é um problema urgente e sensível, responde em áudio com entonação emocional adequada (tom de cuidado e atenção)
- Pode incluir perguntas do tipo: "Você sabe o que tinha nas bolachas? Ele já apresentou algum sintoma?"

#### 🤳 Imagem + contexto inteligente:
- O usuário envia uma selfie de manhã, em frente ao espelho
- Safira detecta que há uma entrevista marcada (cruzamento com a agenda), analisa a imagem e responde com sugestões naturais:
  > "Você tá ótimo! Só ajeita o colarinho e tenta sorrir um pouco mais. Vai arrasar na entrevista. 😄"

Todos os exemplos acima são moldados por um **sistema de contexto emocional e relacional**. Isso significa que a Safira adapta seu **estilo de resposta** ao perfil de relacionamento construído com o usuário:
- Se o usuário trata a Safira como funcionária, ela responde com formalidade e eficiência
- Se trata como amiga, ela usa uma linguagem mais leve e próxima
- Se o relacionamento evolui para algo mais íntimo (tom romântico, afetivo), a Safira responde na mesma linha, com respeito e coerência emocional

A experiência de usar a Safira é como conversar com alguém que te conhece profundamente e sabe o tom exato pra cada situação.

---


## 🧱 Arquitetura Geral (Dockerized Stack)

A stack é composta por múltiplos containers especializados, todos orquestrados via `docker-compose`. A comunicação entre eles ocorre na rede interna `safira-net`.

### 🧩 Serviços principais

| Nome           | Imagem/Base                     | Função                                 |
|----------------|----------------------------------|----------------------------------------|
| safira-core    | n8nio/n8n                        | Motor de automação                     |
| whatsapp       | venom customizado (Node.js)      | Interface com WhatsApp via Webhook     |
| llm-ollama     | ollama/ollama                    | Modelo de linguagem local (LLM)        |
| whisper        | openai/whisper (via CPU, int8)   | STT (áudio → texto)                    |
| tts            | coqui-ai/tts → agora XTTSv2      | TTS (texto → áudio)                    |
| postgree       | postgres:16                      | Banco de dados                         |
| wiki           | requarks/wiki:2                  | Documentação (Wiki.js substituindo Jira) |
| redis          | redis:7                          | Cache e armazenamento leve             |

---

### 🔉 Voz (Entrada e Saída)

| Nome     | Função                                   | Tags |
|----------|-------------------------------------------|------|
| Whisper  | STT: Transcrição de voz para texto       | output, audio |
| XTTSv2   | TTS: Conversão de texto para voz humanizada | input, audio |

### 📊 Administração e Observabilidade

| Nome        | Função                          | Tags |
|-------------|----------------------------------|------|
| Prometheus  | Coleta de métricas               | admin |
| Grafana     | Dashboards e visualização        | admin |
| Wiki.js     | Documentação interna do projeto  | admin |

---


## 📂 Estrutura do Repositório

A estrutura de diretórios da Safira é organizada de forma modular e autogerada pelo script `run.sh`. Isso garante que todos os serviços personalizados tenham seus arquivos essenciais criados dinamicamente, evitando falhas de build e facilitando onboarding.

```bash
safira-wamgia/
├── build/                    # Diretório base para todos os serviços customizados
│   ├── venom/                # Serviço WhatsApp (venom-bot + main.js + Dockerfile personalizado)
│   ├── ollama/               # LLM local para processamento de linguagem (base: Ollama)
│   ├── whisper/              # STT (Speech-to-Text) com Faster-Whisper
│   ├── tts/                  # TTS (Text-to-Speech) com Coqui TTS + API Flask
│   ├── jira/                 # Integração com Jira para gestão de tarefas e automações
│   ├── postgres/             # Banco de dados relacional PostgreSQL (n8n, sessões, histórico)
├── db/                       # Dados persistentes ou seeds iniciais de banco (ex: usuários, configs)
├── workflows/                # Fluxos n8n reutilizáveis, templates, modelos e integrações
├── .env                      # Arquivo de variáveis de ambiente (auto-gerado pelo run.sh)
├── .env.example              # Modelo base para configuração do ambiente local
├── docker-compose.yml        # Orquestrador principal da stack com todos os containers
├── run.sh                    # Script principal que inicializa, configura e sobe toda a stack
```
---

## 🛠️ Setup Inicial

Todo o processo de preparação, configuração e execução da stack Safira é realizado exclusivamente através do script `run.sh`. Esse script é interativo, autodocumentado e modular, permitindo subir serviços individualmente ou reiniciar a stack inteira com segurança.

### ✅ O que o `run.sh` faz:
- Verifica se Docker e Docker Compose estão corretamente instalados
- Garante a existência do arquivo `.env`, criando a partir do `.env.example` se necessário
- Valida e solicita secrets ausentes (como senhas de Redis, Postgres, MinIO, etc.)
- Cria diretórios essenciais e arquivos mínimos para cada serviço personalizado (como Venom, Coqui, Whisper, BLIP2, SESANE...)
- Clona repositórios base (ex: Stable Diffusion)
- Verifica se os Dockerfiles necessários estão presentes e prontos
- Executa o `docker compose up -d --build`
- Exibe os principais endpoints acessíveis da plataforma

### 🚀 Como rodar:
1. Clone o repositório e dê permissão de execução ao script:

```bash
git clone https://github.com/caioross/Safira-WAMGIA.git
cd safira-wamgia
chmod +x run.sh
```

2. Inicie a stack:
```bash
./run.sh
```

---

## 🌐 Endpoints

Abaixo estão listados os principais endpoints HTTP expostos pelos serviços da stack local. Essas portas são mapeadas diretamente no `docker-compose.yml` e podem ser acessadas no navegador ou via API local.

| Componente           | Descrição                                     | URL                                |
|----------------------|-----------------------------------------------|-------------------------------------|
| N8N Core             | Automação de fluxos (assistente principal)    | http://localhost:5678              |
| Venom API (WhatsApp) | Integração com WhatsApp via venom-bot         | http://localhost:3000              |
| LLM Ollama           | Modelo de linguagem local                     | http://localhost:11434             |
| Whisper STT          | Transcrição de áudio para texto               | http://localhost:9000              |
| TTS                  | Geração de fala a partir de texto             | http://localhost:9001              |
| Jira                 | Gerenciamento de tarefas                      | http://localhost:8082              |

| Componente Interno   | Descrição                                     | Porta Interna                      |
|----------------------|-----------------------------------------------|-------------------------------------|
| PostgreSQL           | Banco de dados relacional                     | 5432                               |

> 💡 Observação: Serviços internos como PostgreSQL não expõem interface web, mas são essenciais para o funcionamento interno da stack. e Redis não possuem interface HTTP, mas estão disponíveis para conexões internas entre containers.

---

## ♻️ Ciclo CI/CD

| Branch             | Uso                             |
|--------------------|----------------------------------|
| `develop`          | Desenvolvimento ativo            |
| `release/x.y.z`    | Versão candidata                |
| `main`             | Versão estável                   |

---

## 🔍 Roadmap

- [x] WhatsApp conectado com fluxo webhook estável
- [x] Substituição do Coqui por XTTSv2
- [x] Integração com Whisper (STT)
- [x] Agente de decisão entre texto/áudio
- [x] Substituição do Jira pela Wiki.js
- [ ] Interface web para onboarding e usuários múltiplos
- [ ] Camada de autenticação segura para agentes externos
- [ ] Integração com Google Calendar / Trello / Email
- [ ] Orquestrador de múltiplos fluxos simultâneos

> 📌 Observação: O foco é funcionalidade local, offline-friendly e com resiliência total à falta de cloud.
---

## 🧪 Testes Locais

Recomenda-se testar:
- Envio de mensagens de texto e áudio reais
- Logs via `docker compose logs -f whatsapp`
- Status via `run.sh --status`

## 📄 Licença

Este projeto é **Particular**. Reprodução, distribuição ou uso sem permissão expressa está proibido.

✨ **Happy coding!**  
Equipe Safira WAMGIA 🔮🚀
