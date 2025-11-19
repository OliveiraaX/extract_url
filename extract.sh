#!/bin/bash
# ==================================
# Script: extract.sh
# Autor: Dhiones 
# Objetivo: Extrair links de forma organizada, seguindo apenas o mesmo domínio
# Requisitos: curl, dig
# ==================================

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Banner
echo -e "${CYAN}${BOLD}"
cat << "EOF"
╔═══════════════════════════════════════╗
║     LINK EXTRACTOR & CRAWLER v2.0     ║
║        Focused Domain Crawling        ║
╚═══════════════════════════════════════╝
EOF
echo -e "${NC}"

# Validação de argumentos
if [ -z "$1" ]; then
    echo -e "${RED}[!] Uso: $0 <URL inicial>${NC}"
    echo -e "${YELLOW}    Exemplo: $0 https://example.com${NC}"
    exit 1
fi

START_URL="$1"
MAX_DEPTH=3
MIN_DELAY=1
MAX_DELAY=3
TIMEOUT=5

# Extrair domínio base
BASE_DOMAIN=$(echo "$START_URL" | sed -E 's#https?://([^/]+).*#\1#' | sed 's/^www\.//')

echo -e "${MAGENTA}[i] Domínio Base: ${BOLD}$BASE_DOMAIN${NC}"
echo -e "${MAGENTA}[i] Profundidade Máxima: $MAX_DEPTH${NC}"
echo -e "${MAGENTA}[i] Timeout: ${TIMEOUT}s${NC}\n"

declare -A VISITED
declare -A IP_CACHE
declare -a QUEUE
QUEUE=("$START_URL")
LINK_COUNT=0

# Função para extrair links
extract_links() {
    local url="$1"
    curl -sL --max-time $TIMEOUT "$url" 2>/dev/null \
    | grep -oP 'href="\Khttps?://[^"]+' \
    | sort -u
}

# Função para capturar redirecionamentos
get_redirects() {
    local url="$1"
    curl -sI --max-time $TIMEOUT -L "$url" 2>/dev/null \
    | grep -i "^location:" \
    | sed 's/location: //i' \
    | tr -d '\r'
}

# Função para resolver IP (melhorada com cache)
resolve_ip() {
    local domain="$1"
    
    # Verificar se já está no cache
    if [[ -n "${IP_CACHE[$domain]}" ]]; then
        echo "${IP_CACHE[$domain]}"
        return
    fi
    
    # Tentar com dig primeiro
    local ip=$(dig +short "$domain" A 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -n1)
    
    # Se dig falhar, tentar com host
    if [ -z "$ip" ]; then
        ip=$(host "$domain" 2>/dev/null | grep "has address" | head -n1 | awk '{print $NF}')
    fi
    
    # Se ainda falhar, tentar com getent
    if [ -z "$ip" ]; then
        ip=$(getent hosts "$domain" 2>/dev/null | awk '{print $1}' | head -n1)
    fi
    
    # Salvar no cache
    if [ -n "$ip" ]; then
        IP_CACHE[$domain]="$ip"
    fi
    
    echo "$ip"
}

# Função para verificar se o domínio pertence ao base
is_same_domain() {
    local url="$1"
    local domain=$(echo "$url" | sed -E 's#https?://([^/]+).*#\1#' | sed 's/^www\.//')
    [[ "$domain" == *"$BASE_DOMAIN"* ]]
}

depth=0

echo -e "${BOLD}${BLUE}═══════════════════════════════════════${NC}\n"

while [ ${#QUEUE[@]} -gt 0 ] && [ $depth -lt $MAX_DEPTH ]; do
    CURRENT_URL="${QUEUE[0]}"
    QUEUE=("${QUEUE[@]:1}")
    
    # Pular se já foi visitado
    if [[ -n "${VISITED[$CURRENT_URL]}" ]]; then
        continue
    fi
    
    echo -e "${GREEN}${BOLD}[→] Nível $depth | Visitando:${NC}"
    echo -e "    ${CYAN}$CURRENT_URL${NC}"
    
    # Capturar redirecionamentos
    REDIRECTS=$(get_redirects "$CURRENT_URL")
    if [ -n "$REDIRECTS" ]; then
        echo -e "    ${YELLOW}[⤷] Redirecionamentos detectados:${NC}"
        while IFS= read -r redirect; do
            if [ -n "$redirect" ]; then
                echo -e "        ${YELLOW}↪ $redirect${NC}"
            fi
        done <<< "$REDIRECTS"
    fi
    echo ""
    
    VISITED[$CURRENT_URL]=1
    
    # Delay aleatório
    SLEEP_TIME=$((MIN_DELAY + RANDOM % (MAX_DELAY - MIN_DELAY + 1)))
    sleep $SLEEP_TIME
    
    # Extrair links
    LINKS=$(extract_links "$CURRENT_URL")
    
    if [ -z "$LINKS" ]; then
        echo -e "    ${YELLOW}[!] Nenhum link encontrado${NC}\n"
        continue
    fi
    
    echo -e "    ${BOLD}Links encontrados:${NC}"
    
    for LINK in $LINKS; do
        # Verificar se é do mesmo domínio
        if ! is_same_domain "$LINK"; then
            echo -e "    ${RED}[✗]${NC} $LINK ${RED}(domínio externo - ignorado)${NC}"
            continue
        fi
        
        LINK_COUNT=$((LINK_COUNT + 1))
        
        # Extrair domínio
        DOMAIN=$(echo "$LINK" | sed -E 's#https?://([^/]+).*#\1#')
        
        # Verificar se já temos o IP no cache
        if [[ -n "${IP_CACHE[$DOMAIN]}" ]]; then
            # Já resolvido, mostrar do cache
            echo -e "    ${GREEN}[✓]${NC} $LINK ${CYAN}(cached)${NC}"
            IP="${IP_CACHE[$DOMAIN]}"
            echo -e "        ${BLUE}└─ IP: $IP${NC}"
        else
            # Resolver IP pela primeira vez
            IP=$(resolve_ip "$DOMAIN")
            
            if [ -n "$IP" ]; then
                echo -e "    ${GREEN}[✓]${NC} $LINK"
                echo -e "        ${BLUE}├─ Domínio: $DOMAIN${NC}"
                echo -e "        ${BLUE}└─ IP: $IP${NC}"
            else
                echo -e "    ${GREEN}[✓]${NC} $LINK"
                echo -e "        ${BLUE}├─ Domínio: $DOMAIN${NC}"
                echo -e "        ${YELLOW}└─ IP: Não resolvido (possível erro de DNS)${NC}"
            fi
        fi
        
        # Adicionar à fila se ainda não foi visitado
        if [[ -z "${VISITED[$LINK]}" ]]; then
            QUEUE+=("$LINK")
        fi
    done
    
    echo -e "\n${BLUE}───────────────────────────────────────${NC}\n"
    depth=$((depth + 1))
done

# Resumo final
echo -e "${BOLD}${GREEN}"
cat << "EOF"
╔═══════════════════════════════════════╗
║          CRAWLER FINALIZADO           ║
╚═══════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${MAGENTA}[i] Total de páginas visitadas: ${BOLD}${#VISITED[@]}${NC}"
echo -e "${MAGENTA}[i] Total de links do mesmo domínio: ${BOLD}$LINK_COUNT${NC}"
echo -e "${MAGENTA}[i] Subdomínios únicos encontrados: ${BOLD}${#IP_CACHE[@]}${NC}"
echo -e "${MAGENTA}[i] Domínio analisado: ${BOLD}$BASE_DOMAIN${NC}\n"

# Listar subdomínios encontrados
if [ ${#IP_CACHE[@]} -gt 0 ]; then
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════"
    echo -e "    Subdomínios e IPs Descobertos"
    echo -e "═══════════════════════════════════════${NC}\n"
    for domain in "${!IP_CACHE[@]}"; do
        echo -e "  ${GREEN}•${NC} ${BOLD}$domain${NC} ${BLUE}→${NC} ${YELLOW}${IP_CACHE[$domain]}${NC}"
    done
    echo ""
fi
