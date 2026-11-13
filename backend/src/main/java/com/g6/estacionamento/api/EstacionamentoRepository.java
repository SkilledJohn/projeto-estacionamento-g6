package com.g6.estacionamento.api;

import java.math.BigDecimal;
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

    public BigDecimal registrarSaida(String placa) {
        jdbc.update("CALL app.sp_registrar_saida(?)", placa);
        return jdbc.queryForObject(
            "SELECT r.valor_tarifa FROM app.registro_estacionamento r " +
            "JOIN app.veiculo v ON r.id_veiculo = v.id " +
            "WHERE v.placa = ? ORDER BY r.data_saida DESC LIMIT 1",
            BigDecimal.class,
            placa
        );
    }
}
