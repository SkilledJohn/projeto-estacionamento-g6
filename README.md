# G6 - Sistema de Gestão de Estacionamento (Projeto Integrador)

Este projeto é uma Single Page Application (SPA) para gestão de um estacionamento rotativo interno, focada em alta segurança, performance e arquitetura distribuída.

## Arquitetura e Tecnologias
* **Frontend:** Vanilla JavaScript (SPA), HTML5, Bootstrap 5.
* **Backend:** Java 17, Spring Boot 3, Spring Data JDBC.
* **Banco de Dados:** PostgreSQL 16.
* **Pool de Conexões:** PgBouncer (Otimização de tráfego).
* **Orquestração:** Docker & Docker Compose.

## Hardening e Requisitos de Banco de Dados Atendidos
* **Criptografia Avançada:** Autenticação via `scram-sha-256`.
* **Isolamento de Schemas:** Separação entre dados operacionais (`app`) e logs de segurança (`audit`).
* **RBAC (Role-Based Access Control):** Papéis estritos (`rl_leitor`, `rl_escritor`) sem uso de superusuários na aplicação.
* **RLS (Row-Level Security):** Políticas ativas para impedir visualização de logs de auditoria por usuários não autorizados.
* **Lógica no Banco:** Cálculo de tarifas automatizado via `FUNCTIONS` e `PROCEDURES`.
* **Auditoria Contínua:** `TRIGGERS` registrando automaticamente quem alterou as tabelas e quando.
* **Performance:** Arquivos `postgresql.conf` e `pg_hba.conf` otimizados para pooling e restrição de IPs da rede Docker (`172.20.0.0/16`).

## Como Executar o Projeto

1. **Subir a Infraestrutura (Banco + PgBouncer):**
   ```bash
   docker compose up -d