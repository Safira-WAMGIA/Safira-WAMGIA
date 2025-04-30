-- init-jira.sql
CREATE DATABASE jiradb;

-- Permissões para o usuário definido no .env
GRANT ALL PRIVILEGES ON DATABASE jiradb TO ${POSTGRES_USER};
