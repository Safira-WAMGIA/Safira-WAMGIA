# 🔷 Safira WAMGIA


![Build Status](https://img.shields.io/github/actions/workflow/status/caioross/Safira-WAMGIA/safira-ci.yml?branch=main&label=Build%20Status&style=flat-square&logo=github-actions&logoColor=white)  

![Última Atualização](https://img.shields.io/github/last-commit/caioross/Safira-WAMGIA?style=flat-square&logo=github&logoColor=white)  

![Issues Abertas](https://img.shields.io/github/issues/caioross/Safira-WAMGIA?style=flat-square&logo=github&logoColor=white)  

![Pull Requests Abertos](https://img.shields.io/github/issues-pr/caioross/Safira-WAMGIA?style=flat-square&logo=github&logoColor=white)  

![Linguagem Principal](https://img.shields.io/github/languages/top/caioross/Safira-WAMGIA?style=flat-square&logo=github&logoColor=white)  

![Tamanho do Repositório](https://img.shields.io/github/repo-size/caioross/Safira-WAMGIA?style=flat-square&logo=github&logoColor=white)  

---
**Safira WAMGIA** é uma plataforma integrada de automação e inteligência artificial projetada para assistentes pessoais, interações multimodais e automação de fluxos, com o WhatsApp como principal canal de comunicação. A plataforma utiliza uma arquitetura baseada em microsserviços, garantindo escalabilidade, modularidade e facilidade de manutenção.

---

## 🚀 Visão Geral da Arquitetura

A **Safira WAMGIA** é estruturada em módulos independentes, utilizando **Docker Compose** para orquestração de containers e isolamento de ambiente. A stack completa inclui:

- **Bases de Dados**: PostgreSQL, Redis, MinIO (Object Storage)
- **Orquestração e Gateway**: Traefik
- **Core Workflow**: N8N
- **IA e Serviços**:
  - LLaMA (Ollama): Modelos locais de IA para NLP
  - Venom-bot: Integração com WhatsApp
  - FastAPI: Backend para CSM, TTS/STT e processamento de imagens
- **Observabilidade**: Prometheus, Grafana, Loki
- **CI/CD**: Jenkins, GitHub Actions
- **Apps de Gestão**: Jira Software

---

## 📂 Estrutura do Repositório

```
safira-wamgia/
├── ai-functions        # Funções personalizadas de IA
├── backup              # Serviços de backup
├── csm                 # Serviço para Speech Synthesis (TTS)
├── docs                # Documentação via MkDocs
├── image
│   ├── input           # Processamento de imagens (OCR)
│   └── output          # Geração de imagens via IA
├── loki                # Configuração do Loki para logging centralizado
├── prometheus          # Monitoramento de métricas
├── traefik             # Gateway e proxy reverso
├── venom               # Integração WhatsApp (Venom-bot)
├── voice
│   └── input           # Speech Recognition (STT)
├── shared              # Recursos compartilhados entre serviços
├── .env                # Variáveis de ambiente (template)
├── docker-compose.yml  # Orquestrador principal
├── run.sh              # Script principal de execução
├── setup.sh            # Configuração inicial automatizada
└── secrets.sh          # Gestão de secrets Docker
```

---

## 🛠️ Pré-requisitos

Certifique-se de que você possui as seguintes dependências instaladas antes de continuar:

- **Docker**: >= 24.x
- **Docker Compose Plugin**: >= 2.20.x
- **Bash**: >= 5.x
- **Git**: >= 2.x

---

## ⚙️ Setup Inicial

Para configurar e iniciar o ambiente, siga as instruções abaixo:

1. Clone o repositório:
   ```bash
   git clone https://github.com/caioross/Safira-WAMGIA.git
   cd safira-wamgia
   ```

2. Configure os scripts:
   ```bash
   chmod +x setup.sh run.sh secrets.sh
   ./setup.sh
   ./secrets.sh
   ```

> 🚨 **Nota**: Em ambientes Docker Swarm, os secrets serão configurados automaticamente. Para desenvolvimento local, utilize a flag `--dev`.

---

## 🐳 Gerenciamento de Serviços com Docker

Use o script `run.sh` para gerenciar facilmente a stack Safira:

| Comando                       | Descrição                                    |
|-------------------------------|----------------------------------------------|
| `./run.sh up`                 | Subir todos os serviços                     |
| `./run.sh down`               | Parar todos os serviços                     |
| `./run.sh restart`            | Reiniciar a stack completa                  |
| `./run.sh status`             | Consultar o status atual da stack           |
| `./run.sh logs <serviço>`     | Exibir logs de um serviço específico (com `--save` para salvar os logs) |

---

## 🧩 Componentes e Endpoints

| **Componente**      | **Descrição**                          | **Endpoint**                    |
|---------------------|----------------------------------------|----------------------------------|
| **N8N Core**        | Workflow automation principal         | [http://localhost:5678](http://localhost:5678) |
| **N8N Admin**       | Administração de workflows            | [http://localhost:5680](http://localhost:5680) |
| **Venom API**       | Integração com WhatsApp               | [http://localhost:3001](http://localhost:3001) |
| **Ollama (LLaMA)**  | Modelos locais de IA para NLP         | [http://localhost:11434](http://localhost:11434) |
| **MinIO**           | Armazenamento de objetos (S3)         | [http://localhost:9001](http://localhost:9001) |
| **Grafana**         | Dashboard para métricas e logs        | [http://localhost:3000](http://localhost:3000) |
| **Prometheus**      | Monitoramento de métricas             | [http://localhost:9090](http://localhost:9090) |
| **Traefik**         | Gateway de acesso e proxy reverso     | [http://localhost](http://localhost) |

---

## 🔐 Gestão de Secrets

O script `secrets.sh` permite gerenciar os segredos da aplicação de forma segura. Segredos incluem:

- Senhas do PostgreSQL (Safira, Pagamento, Jira)
- Senhas do Redis e MinIO
- Tokens JWT e secrets do Supabase
- Senha do administrador do Grafana

### Gerar ou atualizar secrets:
```bash
./secrets.sh
```

---

## 📖 Documentação

A documentação técnica é gerada com **MkDocs**. Para visualizar:

```bash
cd docs
mkdocs serve
```
Acesse a documentação em: [http://localhost:8000](http://localhost:8000).

---

## 🔄 Integração Contínua (CI/CD)

- **GitHub Actions**: Pipelines de validação (linting, testes unitários e build de imagens Docker).
- **Jenkins**: Pipelines avançados para integração e deployment contínuos.

---

## 📊 Observabilidade e Logs

- **Métricas**: Monitoramento integrado com Prometheus e Grafana.
- **Logs Centralizados**: Gerenciados pelo Loki com visualização em Grafana.

---

## ✨ Recursos Suportados

| **Recurso**                  | **Status**       | **Observação**                        |
|------------------------------|------------------|---------------------------------------|
| Integração WhatsApp (Venom)  | ✅ Concluído     |                                       |
| Automação de Workflows (N8N) | ✅ Concluído     |                                       |
| Suporte a Multi-idiomas      | 🚧 Em Progresso | PT-BR implementado; EN e ES pendentes |
| Cache Inteligente            | ⬜ Planejado    |                                       |
| Integração com Gateways      | ⬜ Planejado    |                                       |

---

## ❓ FAQ

**1. O que fazer se o Docker Compose falhar com um erro de rede?**  
Verifique se o Docker está devidamente configurado e com privilégios administrativos. Reexecute o comando `docker-compose up` com a flag `--force-recreate`.

**2. Como adicionar novos secrets ao projeto?**  
Use o script `secrets.sh` para gerenciar novos secrets de forma segura.

---

## 🤝 Como Contribuir

1. Faça um fork do projeto:
   ```bash
   git checkout -b feature/nova-funcionalidade
   ```

2. Realize commits claros:
   ```bash
   git commit -m "Descrição concisa"
   ```

3. Envie um pull request detalhado para revisão.

---

## 📜 Licença

Este projeto é **Particular** e não está disponível para uso público sem autorização.

---

## 🚩 Roadmap Futuro

- [ ] Melhoria na arquitetura de filas e workers.
- [ ] Implementação de caching inteligente.
- [ ] Integração completa com gateways de pagamento.
- [ ] Suporte multi-idioma completo (PT, EN, ES).
- [ ] Expansão para serviços cloud (AWS/GCP/Azure).

---

✨ **Happy coding!**  
Equipe Safira WAMGIA 🔮🚀