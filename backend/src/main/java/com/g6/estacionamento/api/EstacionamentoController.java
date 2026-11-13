package com.g6.estacionamento.api;

import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/estacionamento")
@CrossOrigin(origins = "*")
public class EstacionamentoController {

    private final EstacionamentoRepository repository;

    public EstacionamentoController(EstacionamentoRepository repository) {
        this.repository = repository;
    }

    @GetMapping("/vagas")
    public Object listarVagas() {
        return repository.listarVagasOcupadas();
    }

    @PostMapping("/entrada")
    public String registrarEntrada(@RequestParam String placa, @RequestParam String modelo) {
        repository.registrarEntrada(placa, modelo);
        return "Entrada registrada com sucesso!";
    }

    @PostMapping("/saida")
    public String registrarSaida(@RequestParam String placa) {
        repository.registrarSaida(placa);
        return "Saída registrada! Tarifa calculada no banco de dados.";
    }
}