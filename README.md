# SIMAUD (Self-hosted)

Este proyecto es una aplicacion React + Vite que utiliza Supabase (Postgres, autenticacion y funciones Edge) como backend.  
Los ajustes introducidos permiten desplegar todo en un VPS Ubuntu con Supabase auto-hospedado, sin depender de la nube.

## Puntos clave
- Frontend construido con Vite/React y Tailwind.
- Supabase CLI + Docker para levantar la base de datos, la API y las funciones en el mismo servidor.
- Variables de entorno centralizadas para evitar cambios de codigo al mover credenciales.
- Script `scripts/setup_vps.sh` que automatiza la instalacion desde un VPS limpio.

## Variables de entorno
1. Copia `.env.example` a `.env.local` (desarrollo) o `.env` (build/produccion):
   ```bash
   cp .env.example .env.local
   ```
2. Sustituye los valores de `VITE_SUPABASE_URL` y `VITE_SUPABASE_ANON_KEY` por los generados por Supabase.  
   - En local, cuando Supabase CLI crea los contenedores, normalmente sera `http://localhost:54321`.
   - En produccion apunta a la URL publica que exponga tu reverse proxy (`https://tudominio.com`, etc.).

El script de instalacion intenta rellenar automaticamente estas variables si Supabase CLI entrega las credenciales; revisa el resultado al finalizar.

## Flujo tipico en un VPS Ubuntu
1. Conectate al servidor y coloca el repositorio (por `git clone`, `scp`, etc.).  
2. Otorga permisos de ejecucion al script:
   ```bash
   chmod +x scripts/setup_vps.sh
   ```
3. Ejecuta el asistente:
   ```bash
   sudo scripts/setup_vps.sh
   ```
4. Sigue las indicaciones en pantalla. El script:
   - Actualiza el sistema e instala Docker + Docker Compose plugin.
   - Instala Node.js 20 LTS y (opcionalmente) PNPM.
   - Instala Supabase CLI y arranca los contenedores (`supabase start`).
   - Aplica las migraciones de `supabase/migrations`.
   - Genera/actualiza `.env.local` y `.supabase/credentials` con los tokens entregados por Supabase.
   - Instala dependencias del frontend (`npm install`) y ofrece un build opcional.

5. Revisa los mensajes finales: si queda algun paso manual (DNS, SSL, editar credenciales especificas) estara resaltado.

## Desarrollo local
1. Instala dependencias:
   ```bash
   npm install
   ```
2. Arranca Supabase localmente:
   ```bash
   npx supabase start
   ```
3. Configura las variables de entorno (ver seccion anterior).  
4. Arranca la app:
   ```bash
   npm run dev
   ```

## Estructura relevante
- `src/`: codigo del frontend.
- `supabase/migrations`: esquemas y seeds de la base de datos.
- `supabase/functions`: funciones Edge (Deno) consumidas por el frontend.
- `scripts/setup_vps.sh`: asistente de instalacion para VPS limpios.

## Pasos manuales habituales (no automatizados)
- Configurar un dominio y certificados SSL (Nginx, Caddy, Traefik, etc.).
- Ajustar politicas CORS o JWT si se cambia la URL publica.
- Programar copias de seguridad (por ejemplo `pg_dump` via cron).

Con esta estructura no es necesario modificar codigo para apuntar a diferentes entornos; basta con actualizar las variables de entorno.
