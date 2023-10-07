// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract SubastaEspectro {
    string[] public categoriasEspectro = ["BandaAncha", "BandaMedia", "BandaEstrecha", "5G", "B12"]; // Puedes agregar más categorías según sea necesario
    string[] public tiposFrecuencia = ["Banda1", "Banda2", "Banda3", "Tipo4", "Tipo5"]; // Ejemplo: Banda 1, Banda 2, Banda 3

    address public entidadReguladora;
    address public ganador;
    uint256 public duracionRonda;
    uint256 public fechaFinRonda;
    uint256 public numeroRonda;
    string public categoriaActual;
    string public tipoFrecuenciaActual;
    IERC20 public tokenEspectro; // Contrato ERC-20 para los tokens de espectro
    uint256 public montoMinimoPuja; // Monto mínimo requerido para realizar una puja
    address[] public listaParticipantes;
    mapping(address => uint256) public ofertas;
    mapping(address => bool) public empresasTelecomAutorizadas;

    event NuevaOferta(address indexed participante, uint256 monto, string categoria, string tipoFrecuencia);
    event RondaCerrada(uint256 numeroRonda, uint256 precioGanador, string categoria, string tipoFrecuencia);
    event AsignacionEspectro(address indexed ganador, uint256 precio, string categoria, string tipoFrecuencia);
    event TransferenciaTokens(address indexed destinatario, uint256 cantidad);
    event EmpresaTelecomAutorizada(address indexed empresa);

    constructor(
        uint256 _duracionRonda,
        string memory _categoriaInicial,
        string memory _tipoFrecuenciaInicial,
        uint256 _montoMinimoPuja,
        address _tokenEspectro
    ) {
        entidadReguladora = msg.sender;
        duracionRonda = _duracionRonda;
        numeroRonda = 1;
        categoriaActual = _categoriaInicial;
        tipoFrecuenciaActual = _tipoFrecuenciaInicial;
        montoMinimoPuja = _montoMinimoPuja;
        tokenEspectro = IERC20(_tokenEspectro); // Establecer el contrato ERC-20 de espectro
    }

    modifier soloEntidadReguladora() {
        require(msg.sender == entidadReguladora, "Solo la entidad reguladora puede llamar a esta funciOn");
        _;
    }

    modifier concursoAbierto() {
        require(block.timestamp < fechaFinRonda, "La ronda ha expirado");
        _;
    }

    function autorizarEmpresaTelecom(address _empresa) external soloEntidadReguladora {
        empresasTelecomAutorizadas[_empresa] = true;
        emit EmpresaTelecomAutorizada(_empresa);
    }

    function hacerOferta(uint256 _monto) external payable concursoAbierto {
        require(_monto >= montoMinimoPuja, "La puja no alcanza el monto minimo requerido");
        require(msg.value > ofertas[ganador], "La oferta debe superar la oferta actual");

        if (ganador != address(0)) {
            // Reembolsar al participante anterior
            address participanteAnterior = ganador;
            uint256 ofertaAnterior = ofertas[participanteAnterior];
            payable(participanteAnterior).transfer(ofertaAnterior);
        }

        if (!esParticipante(msg.sender)) {
            listaParticipantes.push(msg.sender);
        }
        
        ofertas[msg.sender] = msg.value;
        ganador = msg.sender;

        emit NuevaOferta(msg.sender, msg.value, categoriaActual, tipoFrecuenciaActual);
    }

    function cerrarRonda() external soloEntidadReguladora concursoAbierto {
        fechaFinRonda = block.timestamp + duracionRonda;

        emit RondaCerrada(numeroRonda, ofertas[ganador], categoriaActual, tipoFrecuenciaActual);

        // Asignar tokens ERC-20 de espectro al ganador
        uint256 tokensAsignados = ofertas[ganador] * 1000; // Cada unidad de ether equivale a 1000 tokens
        tokenEspectro.transfer(ganador, tokensAsignados);

        emit AsignacionEspectro(ganador, ofertas[ganador], categoriaActual, tipoFrecuenciaActual);

        // Reiniciar ganador y ofertas
        ganador = address(0);
        for (uint256 i = 0; i < listaParticipantes.length; i++) {
            ofertas[listaParticipantes[i]] = 0;
        }
        delete listaParticipantes;
        numeroRonda++;
    }

    function cambiarDuracionRonda(uint256 _nuevaDuracion) external soloEntidadReguladora {
        duracionRonda = _nuevaDuracion;
    }

    function cambiarCategoriaActual(string memory _nuevaCategoria) external soloEntidadReguladora {
        categoriaActual = _nuevaCategoria;
    }

    function cambiarTipoFrecuenciaActual(string memory _nuevoTipoFrecuencia) external soloEntidadReguladora {
        tipoFrecuenciaActual = _nuevoTipoFrecuencia;
    }

    function cambiarMontoMinimoPuja(uint256 _nuevoMonto) external soloEntidadReguladora {
        montoMinimoPuja = _nuevoMonto;
    }

    // Función para obtener el saldo actual de tokens ERC-20 en el contrato
    function obtenerSaldoTokens() external view returns (uint256) {
        return tokenEspectro.balanceOf(address(this));
    }

    // Función auxiliar para verificar si una dirección es un participante
    function esParticipante(address _direccion) internal view returns (bool) {
        for (uint256 i = 0; i < listaParticipantes.length; i++) {
            if (listaParticipantes[i] == _direccion) {
                return true;
            }
        }
        return false;
    }
}
