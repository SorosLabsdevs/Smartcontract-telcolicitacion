// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
// Author: SorosLabs Devs
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract SubastaEspectro is ERC721, Ownable {
    struct Empresa {
        string nombre;
        address direccion;
        bool autorizada;
    }
    
    struct Ronda {
        uint256 id;
        address ganador;
        uint256 ofertaGanadora;
        uint256 timestampFin;
        string categoria;
        string tipoFrecuencia;
    }
    
    struct TokenMetadata {
        string nombreEmpresa;
        address direccionEmpresa;
        uint256 montoPuja;
        uint256 idRonda;
        string categoria;
        string tipoFrecuencia;
    }
    
    mapping(uint256 => TokenMetadata) public tokenMetadata;
    mapping(address => Empresa) public empresas;
    
    string public categoriaActual;
    string public tipoFrecuenciaActual;
    uint256 public montoMinimoPuja;
    uint256 public duracionRonda;
    uint256 public fechaFinRonda;
    uint256 public numeroRonda;
    Ronda[] public historialRondas;
    address[] public listaParticipantes;
    mapping(address => uint256) public ofertas;

    event NuevaOferta(address indexed participante, uint256 monto, string categoria, string tipoFrecuencia);
    event RondaCerrada(uint256 indexed idRonda, address indexed ganador, uint256 precioGanador, string categoria, string tipoFrecuencia);
    event NFTAsignado(address indexed ganador, uint256 indexed tokenId);
    event PenalizacionEmitida(uint256 indexed idRonda, address indexed ganador, string razon);
    event EmpresaAutorizada(address indexed empresa, bool autorizada);

    constructor(
        uint256 _duracionRonda,
        string memory _categoriaInicial,
        string memory _tipoFrecuenciaInicial,
        uint256 _montoMinimoPuja
    ) ERC721("TokenEspectro", "TESP") {
        duracionRonda = _duracionRonda;
        numeroRonda = 1;
        categoriaActual = _categoriaInicial;
        tipoFrecuenciaActual = _tipoFrecuenciaInicial;
        montoMinimoPuja = _montoMinimoPuja;
        fechaFinRonda = block.timestamp + _duracionRonda;
    }

    function registrarEmpresa(string memory _nombre, address _direccion) external onlyOwner {
        empresas[_direccion] = Empresa(_nombre, _direccion, true);
        emit EmpresaAutorizada(_direccion, true);
    }

    function autorizarEmpresa(address _direccion, bool _autorizada) external onlyOwner {
        require(empresas[_direccion].direccion == _direccion, "Empresa no registrada");
        empresas[_direccion].autorizada = _autorizada;
        emit EmpresaAutorizada(_direccion, _autorizada);
    }

    function hacerOferta(uint256 _monto) external {
        require(empresas[msg.sender].autorizada, "Empresa no autorizada para pujar");
        require(_monto >= montoMinimoPuja, "La puja no alcanza el monto minimo requerido");
        if (ofertas[msg.sender] == 0) {
            listaParticipantes.push(msg.sender);
        }
        ofertas[msg.sender] = _monto;
        emit NuevaOferta(msg.sender, _monto, categoriaActual, tipoFrecuenciaActual);
    }

    function cerrarRonda() external onlyOwner {
        require(block.timestamp >= fechaFinRonda, "La ronda aun no ha finalizado");
        address maxBidder = address(0);
        uint256 maxBid = 0;

        for (uint256 i = 0; i < listaParticipantes.length; i++) {
            if (ofertas[listaParticipantes[i]] > maxBid) {
                maxBid = ofertas[listaParticipantes[i]];
                maxBidder = listaParticipantes[i];
            }
        }

        Ronda memory rondaFinalizada = Ronda({
            id: numeroRonda,
            ganador: maxBidder,
            ofertaGanadora: maxBid,
            timestampFin: block.timestamp,
            categoria: categoriaActual,
            tipoFrecuencia: tipoFrecuenciaActual
        });
        historialRondas.push(rondaFinalizada);

        emit RondaCerrada(numeroRonda, maxBidder, maxBid, categoriaActual, tipoFrecuenciaActual);

        if (maxBidder != address(0)) {
            tokenMetadata[numeroRonda] = TokenMetadata({
                nombreEmpresa: empresas[maxBidder].nombre,
                direccionEmpresa: maxBidder,
                montoPuja: maxBid,
                idRonda: numeroRonda,
                categoria: categoriaActual,
                tipoFrecuencia: tipoFrecuenciaActual
            });
            _mint(maxBidder, numeroRonda);
            emit NFTAsignado(maxBidder, numeroRonda);
        }

        for (uint256 i = 0; i < listaParticipantes.length; i++) {
            ofertas[listaParticipantes[i]] = 0;
        }
        delete listaParticipantes;
        numeroRonda++;
        fechaFinRonda = block.timestamp + duracionRonda;
    }

    function emitirPenalizacion(uint256 _idRonda, string memory _razon) external onlyOwner {
        require(_idRonda > 0 && _idRonda <= historialRondas.length, "Ronda no valida");
        Ronda memory ronda = historialRondas[_idRonda - 1];
        require(ronda.ganador != address(0), "No hay ganador para penalizar");
        
        emit PenalizacionEmitida(_idRonda, ronda.ganador, _razon);
        tokenMetadata[_idRonda].nombreEmpresa = string(abi.encodePacked(tokenMetadata[_idRonda].nombreEmpresa, " (PENALIZADO: ", _razon, ")"));
    }
}
