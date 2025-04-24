# 🔷 Safira WAMGIA

![Versão](https://img.shields.io/badge/Versão-2025.04‑rev‑stable-blue?style=flat-square)
![Licença](https://img.shields.io/badge/Licença-Particular-red?style=flat-square)
![Ambiente](https://img.shields.io/badge/Ambiente-Docker%20Compose-blueviolet?style=flat-square)
![Infra](https://img.shields.io/badge/Infraestrutura-Microsserviços-orange?style=flat-square)

![Docker](https://img.shields.io/badge/Docker-24.x-2496ED?logo=docker&logoColor=white&style=flat-square)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white&style=flat-square)
![FastAPI](https://img.shields.io/badge/FastAPI-0.110-009688?logo=fastapi&logoColor=white&style=flat-square)
![n8n](https://img.shields.io/badge/n8n-Core-E85255?logo=n8n&logoColor=white&style=flat-square)
![WhatsApp](https://img.shields.io/badge/WhatsApp-Venom‑bot-25D366?logo=whatsapp&logoColor=white&style=flat-square)


# 🔷 Safira WAMGIA – README 2025

![Versão](https://img.shields.io/badge/Vers%C3%A3o-2025.04%E2%80%91rev%E2%80%91stable-blue?style=flat-square)
![Licença](https://img.shields.io/badge/Licen%C3%A7a-Particular-red?style=flat-square)
![Ambiente](https://img.shields.io/badge/Ambiente-Docker%20Compose-blueviolet?style=flat-square)
![Infra](https://img.shields.io/badge/Infraestrutura-Microsservi%C3%A7os-orange?style=flat-square)

---

## 🧠 Visão Geral

**Safira WAMGIA** é uma assistente pessoal multimodal, executada localmente, com foco em privacidade, automação inteligente e interações emocionais através de voz, texto e imagem. Baseada em **n8n**, **LLMs**, **STT/TTS**, e um conjunto de agentes específicos, a Safira permite workflows personalizados e expansão modular.

---

## 🧱 Arquitetura Geral (Dockerized Stack)

A Safira opera via **Docker Compose**, utilizando 17 containers principais, separados por função:

### 🔹 Core e Inteligência
| Nome            | Função                                 | Tags |
|------------------|-------------------------------------------|------|
| Safira-Core      | Motor principal dos fluxos n8n             | core |
| Whatsapp (Venom) | Integração via WhatsApp (entrada)         | comunicacao |
| LLM-Ollama       | Modelo LLM local (NLP e automação)         | llm, modelo |
| SESANE           | Análise emocional e contexto de voz         | modelo |

### 🔉 Voz (Entrada e Saída)
| Nome     | Função                                   | Tags |
|-----------|-----------------------------------------------|------|
| Whisper   | STT: Transcrição de voz para texto             | output, audio |
| Coqui     | TTS: Conversão de texto para voz humanizada    | input, audio |

### 📊 Administração e Observabilidade
| Nome        | Função                          | Tags |
|-------------|----------------------------------|------|
| Prometheus  | Coleta de métricas                 | admin |
| Grafana     | Dashboards e visualização          | admin |
| Jira        | Gestão de tarefas e roadmap        | admin |
| Jenkins     | CI/CD e automação de deploy        | infra, admin |

### 🌐 Infraestrutura
| Nome     | Função                                | Tags |
|----------|------------------------------------|------|
| Traefik  | Gateway reverso / proxy dinâmico   | infra |
| NGINXS   | Webserver / roteamento interno     | infra |
| Redis    | Cache e mensagens leves            | infra |
| MinIO    | Armazenamento de objetos (S3-like) | infra |
| Postgree | Banco de dados principal           | infra, core |

### 🖼️ Imagem (Input/Output)
| Nome               | Função                                | Tags |
|--------------------|------------------------------------------|------|
| BLIP2              | Leitura e compreensão de imagens          | imagem, input |
| Stable Diffusion   | Geração de imagens via texto (T2I)       | imagem, output |

---

## 📂 Estrutura do Repositório

A estrutura de diretórios da Safira é organizada de forma modular e autogerada pelo script `run.sh`. Isso garante que todos os serviços personalizados tenham seus arquivos essenciais criados dinamicamente, evitando falhas de build e facilitando onboarding.

```bash
safira-wamgia/
├── build/                    # Diretório base para todos os serviços customizados
│   ├── venom/                # Serviço WhatsApp (venom-bot + main.js + Dockerfile)
│   ├── ollama/               # LLM local (base: ollama)
│   ├── sesame/               # Agente SESANE
│   ├── whisper/              # STT via Faster-Whisper
│   ├── coqui/                # TTS via Coqui TTS + Flask
│   ├── blip2/                # Leitor de imagens com BLIP2
│   ├── auto1111/             # Geração de imagem (Stable Diffusion)
│   ├── jira/                 # Gestão de tarefas (base: Jira)
│   ├── jenkins/              # Automação CI/CD (Jenkins)
│   ├── prometheus/ grafana/  # Monitoramento
│   ├── traefik/ 
│   ├── nginxs/ 
│   ├── redis/ 
│   ├── minio/ 
│   ├── postgres/
├── db/                       # Dados persistentes ou iniciais de banco (se usado)
├── docs/                     # Documentação do projeto (ex: MkDocs)
├── workflows/                # Fluxos, modelos e templates de fluxos de trabalho do n8n padrão.
├── scripts/                  # Scripts utilitários: secrets.sh, release.sh, etc.
├── .env                      # Arquivo de variáveis de ambiente (gerado via run.sh)
├── .env.example              # Template base do .env
├── docker-compose.yml        # Orquestrador principal
├── run.sh                    # Script principal: cria tudo e sobe stack
```

### 🧠 Observações
- O `run.sh` cuida da criação dos arquivos `.py`, `Dockerfile`, `main.js` e `package.json` quando ausentes.
- Serviços que exigem setup remoto (ex: Jira) exibirão uma mensagem de orientação no terminal.
- O repositório foi projetado para funcionar de forma plug-and-play local, com baixa dependência de cloud e foco em autonomia.

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

### ⚙️ Flags disponíveis
Você pode usar o `run.sh` com parâmetros adicionais:

| Comando               | Descrição                                        |
|----------------------|--------------------------------------------------|
| `./run.sh`           | Sobe todos os serviços com build automático     |
| `./run.sh --no-build`| Sobe serviços sem recompilar imagens            |
| `./run.sh --reset`   | Derruba tudo, remove volumes e redes            |
| `./run.sh --status`  | Mostra status atual dos serviços                |
| `./run.sh --only-core`| Sobe apenas n8n, WhatsApp, Postgres             |
| `./run.sh --only-ai` | Sobe somente os modelos IA (Whisper, Coqui etc) |

> 🧠 O `run.sh` é seguro, modular e inteligente: roda só o necessário, e nunca executa builds ou resets desnecessários sem confirmação.
bash
git clone https://github.com/caioross/Safira-WAMGIA.git
cd safira-wamgia
chmod +x setup.sh run.sh secrets.sh
./setup.sh
./secrets.sh
```

2. Suba os containers:

```bash
./run.sh up
```

---

## 🌐 Endpoints

Abaixo estão listados os principais endpoints HTTP expostos pelos serviços da stack local. Essas portas são mapeadas diretamente no `docker-compose.yml` e podem ser acessadas no navegador ou via API local.

| Componente           | Descrição                                     | URL                                |
|----------------------|-----------------------------------------------|-------------------------------------|
| N8N Core             | Automação de fluxos (assistente principal)    | http://localhost:5678              |
| Venom API (WhatsApp) | Integração com WhatsApp via venom-bot         | http://localhost:3000              |
| LLM Ollama           | Modelo de linguagem local                     | http://localhost:11434             |
| SESANE               | Análise emocional de voz                      | http://localhost:8003              |
| Whisper STT          | Transcrição de áudio para texto               | http://localhost:9000              |
| Coqui TTS            | Geração de fala a partir de texto             | http://localhost:9001              |
| BLIP2                | Leitura e descrição de imagens                | http://localhost:9003              |
| Stable Diffusion     | Geração de imagem via prompt textual          | http://localhost:7860              |
| Grafana              | Dashboards e visualização de métricas         | http://localhost:3001              |
| Prometheus           | Coletor de métricas                           | http://localhost:9090              |
| Jenkins              | Pipeline CI/CD local                          | http://localhost:8083              |
| Jira                 | Gerenciamento de tarefas                      | http://localhost:8082              |
| Traefik              | Gateway reverso para serviços HTTP            | http://localhost:8080              |
| NGINX                | Servidor de arquivos estáticos / conteúdo     | http://localhost:8081              |
| MinIO Console        | Interface S3 para arquivos e objetos          | http://localhost:9002              |

| Componente Interno   | Descrição                                     | Porta Interna                      |
|----------------------|-----------------------------------------------|-------------------------------------|
| PostgreSQL           | Banco de dados relacional                     | 5432                               |
| Redis                | Cache e pub/sub de mensagens                  | 6379                               |

> 💡 Observação: Serviços internos como PostgreSQL e Redis não expõem interface web, mas são essenciais para o funcionamento interno da stack. e Redis não possuem interface HTTP, mas estão disponíveis para conexões internas entre containers.

---

## 🔐 Secrets e Segurança

Execute `./secrets.sh` para gerar os secrets obrigatórios. O script cobre:
- PostgreSQL, Redis, MinIO
- Tokens de API (Venom, Ollama, Supabase, etc)
- JWTs e secrets de aplicação

---

## ♻️ Ciclo CI/CD

| Branch             | Uso                             |
|--------------------|----------------------------------|
| `develop`          | Desenvolvimento ativo            |
| `release/x.y.z`    | Versão candidata                |
| `main`             | Versão estável                   |

Scripts Bash automatizam o ciclo de releases:
- `./push-dev.sh` → Sobe pra develop
- `./promote-release.sh 1.2.3` → Cria release
- `./promote-main.sh 1.2.3` → Sobe pro main com tag

---

## 📊 Observabilidade

O módulo de observabilidade da Safira garante rastreamento completo da saúde dos serviços, análise de performance e auditoria de eventos. Ele é composto por:

### 📈 Coleta de Métricas
- **Prometheus**: coleta dados de serviços com suporte a `healthchecks`, uso de CPU, memória, tempo de resposta, latência de containers e serviços expostos via Traefik ou FastAPI.
- **Exporters customizados** podem ser adicionados para serviços específicos como PostgreSQL ou Redis, para insights avançados.

### 📊 Visualização e Dashboards
- **Grafana**: conectado ao Prometheus, apresenta dashboards em tempo real com:
  - Status de containers e recursos
  - Métricas de uso por serviço (n8n, LLM, TTS/STT, etc.)
  - Uptime e erros de healthcheck
  - Tráfego do WhatsApp via Venom

> O painel default do Grafana está disponível em `http://localhost:3000` com credenciais configuradas via `secrets.sh`

### 🪵 Logs Centralizados
- **Loki** (opcional): agrega e estrutura logs de todos os containers para análise via Grafana (modo Explore).
- Logs podem ser filtrados por nível (`info`, `warning`, `error`) e por serviço, útil para depuração e auditoria de fluxos.

### 🔔 Alertas e Notificações (planejado)
- Integração futura com **Alertmanager** para notificar incidentes via e-mail, Telegram, Discord ou WhatsApp.

---

## 🔍 Roadmap

### ✅ Concluídos
- [x] Integração com WhatsApp via Venom
- [x] Pipeline de CI/CD local com GitHub Actions + scripts
- [x] Conversão de voz para texto (Whisper) e TTS (Coqui)
- [x] Geração e leitura de imagens com IA (Stable Diffusion + BLIP2)
- [x] Análise emocional com SESANE
- [x] Dashboard de métricas com Grafana + Prometheus
- [x] Secrets automatizados via `secrets.sh`
- [x] Setup completo com `run.sh`, `setup.sh`, `secrets.sh`

### 🧪 Em Execução / Testes
- [ ] Testes unitários automatizados por serviço (pytest, ruff)
- [ ] Testes de stress e carga em Ollama e Whisper
- [ ] Teste de fallback de LLM secundária (ex: GPT4All)
- [ ] Modo "dev" com auto-reload + debug isolado

### 🧩 A Fazer
- [ ] Caching inteligente com Redis para consultas repetidas
- [ ] Orquestração interna de agentes (modo LangChain-like)
- [ ] Documentação de uso para colaborador/analista
- [ ] Criação de perfil de execução leve (modo "mínimo")
- [ ] Fallbacks para serviços de voz (STT/TTS) em caso de falha
- [ ] Suporte a respostas multimodais nos fluxos n8n
- [ ] Modularização do compose por perfil (admin/core/image/voz)
- [ ] Configuração automática dos containers via script interativo (WIP)

> 📌 Observação: O foco é funcionalidade local, offline-friendly e com resiliência total à falta de cloud.
---

## 📄 Licença

Este projeto é **Particular**. Reprodução, distribuição ou uso sem permissão expressa está proibido.

✨ **Happy coding!**  
Equipe Safira WAMGIA 🔮🚀