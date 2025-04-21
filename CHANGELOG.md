# 📓 CHANGELOG

Todas as mudanças significativas deste projeto serão documentadas aqui.

Este projeto segue o padrão [Keep a Changelog](https://keepachangelog.com/en/1.0.0/) e utiliza [SemVer](https://semver.org/spec/v2.0.0.html).

---

## [Unreleased]
### 🔧 Adicionado
- Integração inicial com agentes especialistas via LLM local.
- Primeiro pipeline CI/CD com validações automáticas.
- Setup inicial da stack dockerizada (n8n, Venom, STT, TTS, Ollama, Redis, PostgreSQL etc).
- Implementação do `run.sh` com auto-verificação da infraestrutura local.

### 🐞 Corrigido
- Corrigido bug onde o container do STT não subia por dependência de modelo não baixado.
- Ajustes de permissão em volumes compartilhados do Docker.

### 🔄 Alterado
- `docker-compose.yml` modularizado com profiles para diferentes ambientes.
- Workflow do GitHub Actions otimizado para rodar apenas em branches relevantes.

---

## [0.1.0] – 2025-04-21
### 🚀 Lançamento Inicial
- Primeira versão instável da Safira.
- Base com infraestrutura modular local usando Docker.
- Integração com WhatsApp via Venom-bot.
- Primeiras automações via n8n com agentes básicos.
- Estrutura de projeto versionada com Git Flow.

---

## 🗂 Histórico de Versões Futuras

### Exemplos de entradas que virão:
#### 🔧 Adicionado
- Suporte a login OAuth via API local.
- Novo container de image-to-text com OCR multimodal.

#### 🔄 Alterado
- Mecanismo de fallback entre modelos de STT.

#### ❌ Removido
- Integração experimental com Supabase (trocado por PostgreSQL puro).

#### 🛠️ Quebra de Compatibilidade
- Alterações na estrutura dos endpoints da API que exigem reconfiguração nos fluxos do n8n.

---

## 📌 Convenções
- `Adicionado` = novos recursos e funcionalidades.
- `Corrigido` = bugs e falhas resolvidas.
- `Alterado` = melhorias ou refatorações sem quebra de compatibilidade.
- `Removido` = funcionalidades ou integrações retiradas.
- `Quebra de Compatibilidade` = mudanças que exigem atenção especial.

