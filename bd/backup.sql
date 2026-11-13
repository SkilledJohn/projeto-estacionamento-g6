-- 1. CRIANDO OS SCHEMAS
CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS audit;

-- 2. GESTÃO DE USUÁRIOS E PERMISSÕES (AAA / RBAC)
CREATE ROLE rl_leitor;
CREATE ROLE rl_escritor;

-- Forçando o uso de scram-sha-256 para criação de usuários
SET password_encryption = 'scram-sha-256';
CREATE USER op_guarita WITH PASSWORD 'senha_forte_123';

-- Concedendo acessos
GRANT USAGE ON SCHEMA app TO rl_leitor, rl_escritor;
GRANT USAGE ON SCHEMA audit TO rl_escritor;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO rl_leitor;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA app TO rl_escritor;
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA audit TO rl_escritor;
GRANT rl_escritor TO op_guarita;

-- 3. CRIAÇÃO DAS TABELAS
CREATE TABLE app.veiculo (
    id SERIAL PRIMARY KEY,
    placa VARCHAR(8) UNIQUE NOT NULL,
    modelo VARCHAR(50) NOT NULL
);

CREATE TABLE app.registro_estacionamento (
    id SERIAL PRIMARY KEY,
    id_veiculo INT NOT NULL REFERENCES app.veiculo(id),
    data_entrada TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    data_saida TIMESTAMP,
    valor_tarifa DECIMAL(10,2)
);

CREATE TABLE audit.log_operacoes (
    id SERIAL PRIMARY KEY,
    tabela_afetada VARCHAR(50),
    acao VARCHAR(20),
    data_hora TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usuario VARCHAR(50),
    detalhes TEXT
);

-- 4. SEGURANÇA: ROW-LEVEL SECURITY (RLS)
-- Ativando RLS na tabela de veículos. Exemplo: Apenas quem tem a role adequada pode visualizar.
ALTER TABLE app.veiculo ENABLE ROW LEVEL SECURITY;
CREATE POLICY policy_veiculo_operador ON app.veiculo
    FOR ALL TO rl_escritor USING (true) WITH CHECK (true);

-- 5. FUNCTION: Calcular Tarifa (Regra de Negócio no SGBD)
CREATE OR REPLACE FUNCTION app.fn_calcular_tarifa(p_entrada TIMESTAMP, p_saida TIMESTAMP)
RETURNS DECIMAL AS $$
DECLARE
    v_horas DECIMAL;
    v_valor_hora DECIMAL := 10.00; -- Tarifa de R$ 10/h
    v_total DECIMAL;
BEGIN
    -- Calcula a diferença em horas (arredondando para cima, ex: 1h10min cobra 2h)
    v_horas := CEIL(EXTRACT(EPOCH FROM (p_saida - p_entrada)) / 3600.0);
    IF v_horas < 1 THEN
        v_horas := 1; -- Cobra mínimo de 1 hora
    END IF;
    v_total := v_horas * v_valor_hora;
    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

-- 6. PROCEDURE: Registrar Saída (Gera o valor e atualiza a tabela)
CREATE OR REPLACE PROCEDURE app.sp_registrar_saida(p_placa VARCHAR)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_registro INT;
    v_data_entrada TIMESTAMP;
    v_data_saida TIMESTAMP := CURRENT_TIMESTAMP;
    v_tarifa DECIMAL;
BEGIN
    -- Busca o registro em aberto pela placa
    SELECT r.id, r.data_entrada INTO v_id_registro, v_data_entrada
    FROM app.registro_estacionamento r
    JOIN app.veiculo v ON r.id_veiculo = v.id
    WHERE v.placa = p_placa AND r.data_saida IS NULL;

    IF v_id_registro IS NULL THEN
        RAISE EXCEPTION 'Nenhum veículo com a placa % encontrado no estacionamento.', p_placa;
    END IF;

    -- Chama a function para calcular a tarifa
    v_tarifa := app.fn_calcular_tarifa(v_data_entrada, v_data_saida);

    -- Atualiza a tabela
    UPDATE app.registro_estacionamento
    SET data_saida = v_data_saida, valor_tarifa = v_tarifa
    WHERE id = v_id_registro;
    
    COMMIT;
END;
$$;

-- 7. TRIGGER: Auditoria de Operações
CREATE OR REPLACE FUNCTION audit.fn_trigger_auditoria()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'DELETE') THEN
        INSERT INTO audit.log_operacoes(tabela_afetada, acao, usuario, detalhes)
        VALUES (TG_TABLE_NAME, 'DELETE', current_user, 'ID: ' || OLD.id);
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        INSERT INTO audit.log_operacoes(tabela_afetada, acao, usuario, detalhes)
        VALUES (TG_TABLE_NAME, 'UPDATE', current_user, 'ID: ' || NEW.id);
        RETURN NEW;
    ELSIF (TG_OP = 'INSERT') THEN
        INSERT INTO audit.log_operacoes(tabela_afetada, acao, usuario, detalhes)
        VALUES (TG_TABLE_NAME, 'INSERT', current_user, 'ID: ' || NEW.id);
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_registro
AFTER INSERT OR UPDATE OR DELETE ON app.registro_estacionamento
FOR EACH ROW EXECUTE FUNCTION audit.fn_trigger_auditoria();

-- 8. VIEWS OBRIGATÓRIAS
CREATE OR REPLACE VIEW app.vw_vagas_ocupadas_agora AS
SELECT v.placa, v.modelo, r.data_entrada 
FROM app.registro_estacionamento r
JOIN app.veiculo v ON r.id_veiculo = v.id
WHERE r.data_saida IS NULL;

CREATE OR REPLACE VIEW app.vw_faturamento_diario AS
SELECT DATE(data_saida) as data_caixa, SUM(valor_tarifa) as total_arrecadado
FROM app.registro_estacionamento
WHERE data_saida IS NOT NULL
GROUP BY DATE(data_saida);

-- 9. SEEDS (Carga Inicial para Testes)
INSERT INTO app.veiculo (placa, modelo) VALUES ('ABC1234', 'Honda Civic'), ('XYZ9876', 'Toyota Corolla');
INSERT INTO app.registro_estacionamento (id_veiculo, data_entrada) VALUES (1, CURRENT_TIMESTAMP - INTERVAL '2 hours');