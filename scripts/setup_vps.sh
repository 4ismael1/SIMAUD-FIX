#!/usr/bin/env bash

set -euo pipefail

LOG_FILE="/var/log/simaud-setup.log"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

log_info() {
  printf '[INFO] %s\n' "$*" | tee -a "$LOG_FILE"
}

log_warn() {
  printf '[WARN] %s\n' "$*" | tee -a "$LOG_FILE" >&2
}

log_error() {
  printf '[ERROR] %s\n' "$*" | tee -a "$LOG_FILE" >&2
}

prompt_yes_no() {
  local prompt="$1"
  local default="${2:-Y}"
  local response
  local suffix="[Y/n]"

  if [[ "$default" == "N" ]]; then
    suffix="[y/N]"
  fi

  while true; do
    read -rp "$prompt $suffix " response || true
    response="${response:-$default}"
    case "${response,,}" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) echo "Por favor responde y/n." ;;
    esac
  done
}

ensure_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    log_error "Ejecuta este script con privilegios de root (usa sudo)."
    exit 1
  fi
}

detect_os() {
  if [[ ! -f /etc/os-release ]]; then
    log_error "No se encontro /etc/os-release. Este script esta pensado para Ubuntu."
    exit 1
  fi

  # shellcheck disable=SC1091
  source /etc/os-release
  if [[ "${ID}" != "ubuntu" ]]; then
    log_error "Sistema operativo no soportado: ${NAME:-desconocido}. Necesitas Ubuntu."
    exit 1
  fi

  UBUNTU_VERSION="${VERSION_ID}"
  UBUNTU_CODENAME="${VERSION_CODENAME}"
  log_info "Detectado Ubuntu ${UBUNTU_VERSION} (${UBUNTU_CODENAME})."
}

setup_logging() {
  touch "$LOG_FILE"
  chmod 600 "$LOG_FILE"
  log_info "Registrando el proceso en $LOG_FILE"
}

update_system() {
  log_info "Actualizando indices de paquetes..."
  apt-get update -y
  log_info "Aplicando actualizaciones minimas..."
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
}

install_base_packages() {
  log_info "Instalando utilidades base (curl, git, jq, etc.)..."
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    git \
    gnupg \
    jq \
    lsb-release \
    unzip
}

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log_info "Docker ya esta instalado."
    return
  fi

  log_info "Instalando Docker Engine..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
${UBUNTU_CODENAME} stable" > /etc/apt/sources.list.d/docker.list

  apt-get update -y
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin

  systemctl enable docker
  systemctl restart docker
  log_info "Docker instalado y servicio activado."
}

add_user_to_docker_group() {
  local user="${SUDO_USER:-}"

  if [[ -z "$user" || "$user" == "root" ]]; then
    log_warn "No se anadio ningun usuario al grupo docker (script ejecutado como root)."
    return
  fi

  if id -nG "$user" | grep -qw docker; then
    log_info "El usuario $user ya pertenece al grupo docker."
    return
  fi

  usermod -aG docker "$user"
  log_info "Usuario $user anadido al grupo docker. Sera necesario cerrar sesion y volver a entrar para que surta efecto."
}

install_node() {
  local required_major=20
  local current_major=0

  if command -v node >/dev/null 2>&1; then
    current_major="$(node -v | sed -E 's/^v([0-9]+).*/\1/')"
  fi

  if [[ "$current_major" -ge "$required_major" ]]; then
    log_info "Node.js $(node -v) encontrado. No se instalara una nueva version."
    return
  fi

  log_info "Instalando Node.js ${required_major}.x desde NodeSource..."
  curl -fsSL https://deb.nodesource.com/setup_"${required_major}".x | bash -
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
  log_info "Node.js $(node -v) instalado."
}

install_supabase_cli() {
  if command -v supabase >/dev/null 2>&1; then
    log_info "Supabase CLI ya esta instalado."
    return
  fi

  log_info "Instalando Supabase CLI globalmente con npm..."
  npm install -g supabase
  log_info "Supabase CLI version $(supabase --version) instalada."
}

ensure_supabase_config() {
  local config_path="$REPO_ROOT/supabase/config.toml"

  if [[ -f "$config_path" ]]; then
    log_info "Archivo supabase/config.toml encontrado."
    return
  fi

  log_info "Creando supabase/config.toml por defecto..."
  cat > "$config_path" <<'EOF'
project_id = "simaud-local"
organization_id = "self_hosted"

[api]
port = 54321
schemas = ["public", "storage", "graphql_public"]
extra_search_path = ["extensions"]
max_rows = 1000

[db]
major_version = 15
port = 54322
shadow_port = 54329
password = "postgres"
branch = "main"

[studio]
port = 54323

[inbucket]
port = 54324

[storage]
port = 54326

[realtime]
port = 54325
EOF
  log_info "Archivo supabase/config.toml generado."
}

start_supabase() {
  log_info "Arrancando servicios de Supabase (esto puede tardar varios minutos la primera vez)..."
  (cd "$REPO_ROOT" && supabase start) | tee -a "$LOG_FILE"
  log_info "Supabase en marcha."
}

extract_supabase_credentials() {
  local status_json
  local status_text

  if status_json="$(cd "$REPO_ROOT" && supabase status --output json 2>/dev/null)"; then
    SUPABASE_API_URL="$(jq -r '.api.url // .services.api.url // empty' <<<"$status_json")"
    SUPABASE_ANON_KEY="$(jq -r '.api.anon_key // .services.api.anon_key // empty' <<<"$status_json")"
    SUPABASE_SERVICE_ROLE_KEY="$(jq -r '.api.service_role_key // .services.api.service_role_key // empty' <<<"$status_json")"
  fi

  if [[ -z "${SUPABASE_API_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
    log_warn "Fallo al extraer credenciales desde JSON, se intenta analizar salida de texto..."
    status_text="$(cd "$REPO_ROOT" && supabase status)"

    SUPABASE_API_URL="$(grep -i 'API URL' <<<"$status_text" | awk -F': ' '{print $2}' | tail -n1)"
    SUPABASE_ANON_KEY="$(grep -i 'anon key' <<<"$status_text" | awk -F': ' '{print $2}' | tail -n1)"
    SUPABASE_SERVICE_ROLE_KEY="$(grep -i 'service role key' <<<"$status_text" | awk -F': ' '{print $2}' | tail -n1)"
  fi

  if [[ -z "${SUPABASE_API_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
    log_error "No se pudieron recuperar las credenciales de Supabase. Revisalas manualmente con 'supabase status'."
    return 1
  fi

  log_info "Credenciales de Supabase obtenidas."
  return 0
}

write_env_files() {
  local env_file="$REPO_ROOT/.env.local"
  local backup_suffix
  local public_url

  log_info "URL detectada por Supabase: ${SUPABASE_API_URL}"

  read -rp "URL publica para VITE_SUPABASE_URL [${SUPABASE_API_URL}]: " public_url
  public_url="${public_url:-$SUPABASE_API_URL}"

  if [[ -f "$env_file" ]]; then
    backup_suffix="$(date +%Y%m%d%H%M%S)"
    if prompt_yes_no "El archivo .env.local ya existe. Crear copia y sobrescribir?" "Y"; then
      cp "$env_file" "${env_file}.bak-${backup_suffix}"
      log_info "Copia de seguridad creada en ${env_file}.bak-${backup_suffix}"
    else
      env_file="$REPO_ROOT/.env.local.generated"
      log_warn "No se sobrescribe .env.local. Se generara ${env_file}."
    fi
  fi

  cat > "$env_file" <<EOF
VITE_SUPABASE_URL=${public_url}
VITE_SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}
EOF

  log_info "Variables de entorno escritas en ${env_file}."

  mkdir -p "$REPO_ROOT/.supabase"
  echo "ANON_KEY=${SUPABASE_ANON_KEY}" > "$REPO_ROOT/.supabase/credentials"
  echo "SERVICE_ROLE_KEY=${SUPABASE_SERVICE_ROLE_KEY}" >> "$REPO_ROOT/.supabase/credentials"
  chmod 600 "$REPO_ROOT/.supabase/credentials"
  log_info "Credenciales adicionales guardadas en .supabase/credentials (permiso 600)."
}

reset_database() {
  if prompt_yes_no "Deseas aplicar las migraciones desde cero con 'supabase db reset'? (recomendado en servidores nuevos)" "Y"; then
    log_info "Reseteando base de datos y aplicando migraciones..."
    (cd "$REPO_ROOT" && supabase db reset --force) | tee -a "$LOG_FILE"
    log_info "Migraciones aplicadas correctamente."
  else
    log_warn "Omitiendo reseteo de base de datos. Asegurate de aplicar migraciones manualmente si es necesario."
  fi
}

build_functions() {
  if prompt_yes_no "Quieres compilar las funciones Edge para verificar errores? (supabase functions build)" "Y"; then
    log_info "Compilando funciones Edge..."
    (cd "$REPO_ROOT" && supabase functions build) | tee -a "$LOG_FILE"
    log_info "Compilacion de funciones finalizada."
  else
    log_warn "Compilacion de funciones omitida."
  fi
}

install_node_dependencies() {
  if [[ -d "$REPO_ROOT/node_modules" ]]; then
    log_info "Dependencias de Node ya instaladas (directorio node_modules encontrado)."
    if prompt_yes_no "Deseas reinstalarlas usando 'npm install'?" "N"; then
      :
    else
      log_warn "Reinstalacion de dependencias omitida."
      return
    fi
  fi

  log_info "Instalando dependencias del frontend..."
  (cd "$REPO_ROOT" && npm install) | tee -a "$LOG_FILE"
  log_info "Dependencias instaladas."
}

build_frontend() {
  if prompt_yes_no "Quieres generar el build de produccion del frontend ahora? (npm run build)" "Y"; then
    log_info "Generando build de produccion..."
    (cd "$REPO_ROOT" && npm run build) | tee -a "$LOG_FILE"
    log_info "Build completado. Archivos listos en dist/."
  else
    log_warn "Build omitido. Puedes ejecutarlo mas tarde con 'npm run build'."
  fi
}

main() {
  ensure_root
  setup_logging
  detect_os
  update_system
  install_base_packages
  install_docker
  add_user_to_docker_group
  install_node
  install_supabase_cli
  ensure_supabase_config
  start_supabase
  extract_supabase_credentials
  write_env_files
  reset_database
  build_functions
  install_node_dependencies
  build_frontend

  log_info "Instalacion completa."
  log_info "Recomendaciones:"
  log_info "- Configura un reverse proxy (NGINX/Caddy) para exponer ${SUPABASE_API_URL} si lo necesitas externamente."
  log_info "- Si anadiste usuarios al grupo docker, reinicia sesion para evitar usar sudo al ejecutar docker."
  log_info "- Revisa ${LOG_FILE} para ver todo el historial de la instalacion."

  if [[ -z "${SUPABASE_SERVICE_ROLE_KEY:-}" ]]; then
    log_warn "No se pudo almacenar la SERVICE_ROLE_KEY automaticamente. Ejecuta 'supabase status' y actualiza .supabase/credentials manualmente."
  fi
}

main "$@"
