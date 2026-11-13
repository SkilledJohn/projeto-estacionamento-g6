package com.g6.estacionamento.api;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class EstacionamentoRepository {

    private final JdbcTemplate jdbc;

    public EstacionamentoRepository(JdbcTemplate jdbc) {
        this.jdbc = jdbc;
    }

    public Object listarVagasOcupadas() {
        return jdbc.queryForList("SELECT * FROM app.vw_vagas_ocupadas_agora");
    }

    public void registrarEntrada(String placa, String modelo) {
        String sqlVeiculo = "INSERT INTO app.veiculo (placa, modelo) VALUES (?, ?) ON CONFLICT (placa) DO NOTHING";
        jdbc.update(sqlVeiculo, placa, modelo);

        String sqlRegistro = "INSERT INTO app.registro_estacionamento (id_veiculo) SELECT id FROM app.veiculo WHERE placa = ?";
        jdbc.update(sqlRegistro, placa);
    }

    public void registrarSaida(String placa) {
        jdbc.update("CALL app.sp_registrar_saida(?)", placa);
    }
}