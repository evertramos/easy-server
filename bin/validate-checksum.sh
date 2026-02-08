#!/bin/bash

# Script para validar checksum de arquivo
# Uso: ./validate_checksum.sh -f <arquivo> -s <checksum> [-md5|-sha256|-sha512]

set -e

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Variáveis
FILE=""
CHECKSUM=""
ALGORITHM="sha256"

# Função de ajuda
show_help() {
    cat << EOF
Uso: $0 -f <arquivo> -s <checksum> [-md5|-sha256|-sha512]

Opções:
    -f        Arquivo para validar
    -s        String do checksum esperado
    -md5      Usar algoritmo MD5
    -sha256   Usar algoritmo SHA256 (padrão)
    -sha512   Usar algoritmo SHA512

Exemplos:
    $0 -f arquivo.txt -s abc123def456...
    $0 -f documento.pdf -s xyz789... -sha512
    $0 -f imagem.jpg -s d41d8cd98f00b204e9800998ecf8427e -md5
EOF
    exit 0
}

# Parse dos argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        -f)
            FILE="$2"
            shift 2
            ;;
        -s)
            CHECKSUM="$2"
            shift 2
            ;;
        -md5)
            ALGORITHM="md5"
            shift
            ;;
        -sha256)
            ALGORITHM="sha256"
            shift
            ;;
        -sha512)
            ALGORITHM="sha512"
            shift
            ;;
        -h|--help)
            show_help
            ;;
        *)
            echo "Opção inválida: $1" >&2
            show_help
            ;;
    esac
done

# Validação dos argumentos obrigatórios
if [ -z "$FILE" ]; then
    echo -e "${RED}Erro: Arquivo não especificado (-f)${NC}" >&2
    show_help
fi

if [ -z "$CHECKSUM" ]; then
    echo -e "${RED}Erro: Checksum não especificado (-s)${NC}" >&2
    show_help
fi

# Verifica se o arquivo existe
if [ ! -f "$FILE" ]; then
    echo -e "${RED}Erro: Arquivo '$FILE' não encontrado${NC}" >&2
    exit 1
fi

# Calcula o checksum baseado no algoritmo
case $ALGORITHM in
    md5)
        CALCULATED=$(md5sum "$FILE" | awk '{print $1}')
        ;;
    sha1)
        CALCULATED=$(sha1sum "$FILE" | awk '{print $1}')
        ;;
    sha256)
        CALCULATED=$(sha256sum "$FILE" | awk '{print $1}')
        ;;
    sha512)
        CALCULATED=$(sha512sum "$FILE" | awk '{print $1}')
        ;;
    *)
        echo -e "${RED}Erro: Algoritmo '$ALGORITHM' não suportado${NC}" >&2
        echo -e "${YELLOW}Algoritmos suportados: md5, sha256, sha512${NC}" >&2
        exit 1
        ;;
esac

# Remove espaços e converte para lowercase para comparação
CHECKSUM_CLEAN=$(echo "$CHECKSUM" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')
CALCULATED_CLEAN=$(echo "$CALCULATED" | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

# Compara os checksums
echo -e "${CYAN}Arquivo:${NC} $FILE"
echo -e "${CYAN}Algoritmo:${NC} ${BLUE}$ALGORITHM${NC}"
echo -e "${CYAN}Checksum esperado:${NC}  $CHECKSUM_CLEAN"
echo -e "${CYAN}Checksum calculado:${NC} $CALCULATED_CLEAN"
echo ""

if [ "$CHECKSUM_CLEAN" = "$CALCULATED_CLEAN" ]; then
    echo -e "${GREEN}✓ SUCESSO: Checksum válido!${NC}"
    exit 0
else
    echo -e "${RED}✗ FALHA: Checksum inválido!${NC}"
    exit 1
fi
