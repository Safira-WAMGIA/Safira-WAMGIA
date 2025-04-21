# 🔷 Safira WAMGIA

**Safira WAMGIA** é uma plataforma integrada de automação e inteligência artificial voltada para assistentes pessoais, interações multimodais e automação de fluxos, utilizando WhatsApp como principal canal. O projeto utiliza tecnologias robustas, como Docker, N8N, FastAPI, LLaMA, Venom-bot e Ollama, com arquitetura baseada em microsserviços para garantir escalabilidade, modularidade e facilidade de manutenção.

---

## 🚀 Visão Geral da Arquitetura

A Safira WAMGIA é dividida em módulos bem definidos, utilizando Docker Compose para orquestração de containers e ambiente isolado. A stack completa inclui:

- **Bases de Dados**: PostgreSQL, Redis, MinIO (Object Storage)
- **Orquestração e Gateway**: Traefik
- **Core Workflow**: N8N
- **IA e Serviços**: LLaMA (Ollama), Venom (WhatsApp), FastAPI (CSM, TTS/STT, Image Processing)
- **Observabilidade**: Prometheus, Grafana, Loki
- **CI/CD**: Jenkins, GitHub Actions
- **Apps de Gestão**: Jira Software

---

## 📂 Estrutura do Repositório
safira-wamgia/ 
├── ai-functions # Funções personalizadas de IA
├── backup # Serviços de backup
├── csm # Serviço para Speech Synthesis (TTS)
├── docs # Documentação via MkDocs
├── image
│ ├── input # Processamento de imagens (OCR)
│ └── output # Geração de imagens via IA
├── loki # Configuração do Loki para logging centralizado
├── prometheus # Monitoramento de métricas
├── traefik # Gateway e proxy reverso
├── venom # Integração WhatsApp (Venom-bot)
├── voice
│ └── input # Speech Recognition (STT)
├── shared # Recursos compartilhados entre serviços
├── .env # Variáveis de ambiente (template)
├── docker-compose.yml # Orquestrador principal
├── run.sh # Script principal de execução
├── setup.sh # Configuração inicial automatizada
└── secrets.sh # Gestão de secrets Docker


---

## 🛠️ Pré-requisitos

- Docker >= 24.x
- Docker Compose Plugin >= 2.20.x
- Bash >= 5.x (para scripts de execução e setup)
- Git >= 2.x

---

## ⚙️ Setup Inicial

Clone o repositório e configure o ambiente automaticamente:

```bash
git clone <repo-url>
cd safira-wamgia
chmod +x setup.sh run.sh secrets.sh
./setup.sh
./secrets.sh
```
🚨 Nota: Se você estiver usando o Docker em modo Swarm, os secrets serão criados automaticamente. Caso contrário, utilize a opção --dev para desenvolvimento local.

## 🐳 Executando a Aplicação
Utilize o run.sh para controlar a stack Safira facilmente:

### Subir todos os serviços
```bash
./run.sh up
```
### Parar todos os serviços
```bash
./run.sh down
```
### Reiniciar a stack completa
```bash
./run.sh restart
```
### Consultar o status atual da stack
```bash
./run.sh status
```
### Visualizar logs de um serviço específico
```bash
./run.sh logs <nome-serviço> --save
```

## 🧩 Componentes e Endpoints

N8N Core (Safira)
- http://localhost:5678
- Workflow automation principal

Admin (N8N)
- http://localhost:5680
- Administração separada de workflows

Venom API
- http://localhost:3001
- API de integração com WhatsApp

Ollama (LLaMA)
- http://localhost:11434
- Modelos locais de IA para NLP

MinIO
- http://localhost:9001
- Armazenamento de objetos (S3)

Grafana
- http://localhost:3000
- Dashboard para métricas e logs

Prometheus
- http://localhost:9090
- Backend de monitoramento de métricas

Traefik
- http://localhost
- Gateway de acesso e proxy reverso

## 🔐 Gestão de Secrets
Secrets gerenciados via Docker Secrets (secrets.sh):

+ Senhas PostgreSQL (Safira, Pagamento, Jira)
+ MinIO Root Password
+ Grafana Admin Password
+ JWT e Secrets do Supabase
+ Redis Password
+ Jenkins Admin Password

Gerar/atualizar secrets:
```bash
./secrets.sh
```

## 📖 Documentação
A documentação técnica é gerada com MkDocs:
```bash
cd docs
mkdocs serve
```
Acesse a documentação em: http://localhost:8000.


## 🔄 CI/CD e DevOps
+ GitHub Actions: Validação automática com lint, testes unitários e build de imagens Docker.
+ Jenkins: Pipelines avançados e gestão contínua de integração e deployment.
+ Watchtower: Atualizações automáticas de containers.

## 📊 Observabilidade e Logs
+ Métricas com Prometheus/Grafana
+ Logs centralizados em Loki com visualização em Grafana.

## 📦 Implantação e Escalabilidade
+ Deployment recomendado em ambiente Docker Swarm ou Kubernetes.
+ Escalonamento horizontal possível via replicação de containers.

## 💡 Boas Práticas Adotadas
+ Princípios SOLID aplicados na organização dos microsserviços.
+ DRY com uso de anchors YAML.
+ Secrets isolados e seguros.
+ Scripts idempotentes e automatizados para setup e manutenção.
+ Healthchecks integrados garantindo disponibilidade.

## 🤝 Contribuição e Issues
Para contribuir:

+ Fork o projeto.

+ Crie um branch para sua feature
```bash
git checkout -b feature/nova-funcionalidade
```

+ Realize commits claros
```bash
git commit -m 'Descrição concisa'
```

+ Abra um pull request detalhado para revisão.
+ Para reportar issues, utilize o sistema de Issues do GitHub, descrevendo detalhadamente o problema ou sugestão.

## 📜 Licença
Este projeto é Particular.

## 🚩 Próximos Passos (Roadmap)
- [ ] Integração completa com gateways de pagamento
- [ ] Melhoria na arquitetura de filas e workers
- [ ] Implementação de caching inteligente
- [ ] Suporte multi-idioma completo (PT, EN, ES)
- [ ] Expansão para serviços cloud (AWS/GCP/Azure)

✨ Happy coding!
Equipe Safira WAMGIA 🔮🚀