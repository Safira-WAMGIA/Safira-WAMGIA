# 🔷 Safira WAMGIA

**Safira WAMGIA** é uma plataforma integrada de automação e inteligência artificial voltada para assistentes pessoais, interações multimodais e automação de fluxos, com o WhatsApp como principal canal. O projeto utiliza tecnologias robustas como Docker, N8N, FastAPI, LLaMA, Venom-bot e Ollama, organizadas em uma arquitetura de microsserviços para escalabilidade, modularidade e facilidade de manutenção.

---

## 🚀 Visão Geral da Arquitetura

A plataforma é estruturada em módulos bem definidos, utilizando **Docker Compose** para orquestração de containers e isolamento do ambiente. A stack inclui:

- **Bases de Dados**: PostgreSQL, Redis, MinIO (Object Storage)
- **Orquestração e Gateway**: Traefik
- **Core Workflow**: N8N
- **IA e Serviços**: LLaMA (Ollama), Venom (WhatsApp), FastAPI (CSM, TTS/STT, Image Processing)
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

- **Docker** >= 24.x
- **Docker Compose Plugin** >= 2.20.x
- **Bash** >= 5.x (para os scripts de execução e setup)
- **Git** >= 2.x

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

> 🚨 **Nota**: Se estiver usando o Docker em modo Swarm, os secrets serão criados automaticamente. Para desenvolvimento local, utilize a opção `--dev`.

---

## 🐳 Executando a Aplicação

Utilize o script `run.sh` para gerenciar a stack Safira:

- **Subir todos os serviços:**
  ```bash
  ./run.sh up
  ```

- **Parar todos os serviços:**
  ```bash
  ./run.sh down
  ```

- **Reiniciar a stack completa:**
  ```bash
  ./run.sh restart
  ```

- **Consultar o status atual da stack:**
  ```bash
  ./run.sh status
  ```

- **Visualizar logs de um serviço específico:**
  ```bash
  ./run.sh logs <nome-serviço> --save
  ```

---

## 🧩 Componentes e Endpoints

| Componente          | Descrição                           | Endpoint                      |
|---------------------|-----------------------------------|-------------------------------|
| **N8N Core**        | Workflow automation principal    | [http://localhost:5678](http://localhost:5678) |
| **N8N Admin**       | Administração separada de workflows | [http://localhost:5680](http://localhost:5680) |
| **Venom API**       | Integração com WhatsApp          | [http://localhost:3001](http://localhost:3001) |
| **Ollama (LLaMA)**  | Modelos locais de IA para NLP    | [http://localhost:11434](http://localhost:11434) |
| **MinIO**           | Armazenamento de objetos (S3)    | [http://localhost:9001](http://localhost:9001) |
| **Grafana**         | Dashboard de métricas e logs     | [http://localhost:3000](http://localhost:3000) |
| **Prometheus**      | Monitoramento de métricas        | [http://localhost:9090](http://localhost:9090) |
| **Traefik**         | Gateway de acesso e proxy reverso | [http://localhost](http://localhost) |

---

## 🔐 Gestão de Secrets

Secrets são gerenciados via **Docker Secrets** utilizando o script `secrets.sh`. Incluem:

- Senhas PostgreSQL (Safira, Pagamento, Jira)
- MinIO Root Password
- Grafana Admin Password
- JWT e secrets do Supabase
- Redis Password
- Jenkins Admin Password

### Gerar ou atualizar secrets:
```bash
./secrets.sh
```

---

## 📖 Documentação

A documentação técnica é gerada com **MkDocs**:

```bash
cd docs
mkdocs serve
```

Acesse a documentação em: [http://localhost:8000](http://localhost:8000).

---

## 🔄 CI/CD e DevOps

- **GitHub Actions**: Validação automática com lint, testes unitários e build de imagens Docker.
- **Jenkins**: Pipelines avançados para integração e deployment contínuos.
- **Watchtower**: Atualizações automáticas de containers.

---

## 📊 Observabilidade e Logs

- **Métricas**: Monitoramento com Prometheus/Grafana.
- **Logs Centralizados**: Utilização de Loki com visualização em Grafana.

---

## 📦 Implantação e Escalabilidade

- **Ambientes Recomendados**: Docker Swarm ou Kubernetes.
- **Escalonamento Horizontal**: Suporte via replicação de containers.

---

## 💡 Boas Práticas Adotadas

- **SOLID**: Princípios aplicados na organização dos microsserviços.
- **DRY**: Uso de anchors YAML para evitar repetição.
- **Segurança**: Secrets isolados e seguros.
- **Automação Completa**: Scripts idempotentes para setup e manutenção.
- **Healthchecks**: Garantia de disponibilidade contínua.

---

## 🤝 Contribuição e Issues

### Como contribuir:
1. Faça um fork do projeto.
2. Crie um branch para sua feature:
   ```bash
   git checkout -b feature/nova-funcionalidade
   ```
3. Realize commits claros:
   ```bash
   git commit -m "Descrição concisa"
   ```
4. Abra um pull request detalhado para revisão.

### Reportar Issues:
Utilize o sistema de Issues do GitHub para descrever problemas ou sugerir melhorias.

---

## 📜 Licença

Este projeto é **Particular**.

---

## 🚩 Próximos Passos (Roadmap)

- [ ] Integração completa com gateways de pagamento.
- [ ] Melhoria na arquitetura de filas e workers.
- [ ] Implementação de caching inteligente.
- [ ] Suporte multi-idioma completo (PT, EN, ES).
- [ ] Expansão para serviços cloud (AWS/GCP/Azure).

---

✨ **Happy coding!**  
Equipe Safira WAMGIA 🔮🚀