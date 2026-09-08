# Infraestructura — FreshBox SpA (EP1 ARY1102)

Plataforma de catálogo online de productos orgánicos con arquitectura de microservicios.

---

## 1. Arquitectura General

```
┌─────────────────────────────────────────────────────────────────────┐
│                         INTERNET                                    │
└──────────────────────────────┬──────────────────────────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │   ALB (Puerto 80)   │
                    │  Subredes Públicas   │
                    │   Multi-AZ (1a,1b)   │
                    └──────────┬──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                                   │
   ┌──────────▼──────────┐           ┌──────────▼──────────┐
   │  EC2 APP-1 (AZ1a)  │           │  EC2 APP-2 (AZ1b)  │
   │   t4g.small ARM     │           │   t4g.small ARM     │
   │   Docker 5 Contenedores         │   Docker 5 Contenedores
   └──────────┬──────────┘           └──────────┬──────────┘
              │                                   │
              └────────────────┬────────────────┘
                               │
                    ┌──────────▼──────────┐
                    │  EC2 MySQL (AZ1a)   │
                    │   t4g.small ARM     │
                    │   freshbox BD       │
                    └─────────────────────┘
```

---

## 2. AWS — Red (VPC)

| Componente | CIDR / Config |
|---|---|
| VPC | `10.0.0.0/22` |
| Subred Pública AZ1a | `10.0.0.0/24` — ALB, NAT Gateway |
| Subred Pública AZ1b | `10.0.1.0/24` — ALB |
| Subred Privada APP AZ1a | `10.0.2.0/24` — EC2 APP-1 |
| Subred Privada APP AZ1b | `10.0.3.0/24` — EC2 APP-2 |
| Subred Privada DATA AZ1a | `10.0.4.0/24` — EC2 MySQL |
| Subred Privada DATA AZ1b | `10.0.5.0/24` — Reserva |
| Internet Gateway | Vinculado a VPC |
| NAT Gateway | AZ1a — salida a internet para subredes privadas |

---

## 3. AWS — Security Groups

### SG-ALB (Ingreso público)

| Protocolo | Puerto | Origen |
|---|---|---|
| TCP | 80 | 0.0.0.0/0 |
| TCP | 443 | 0.0.0.0/0 |

### SG-APP (Ingreso desde ALB)

| Protocolo | Puerto | Origen |
|---|---|---|
| TCP | 80 | SG-ALB |
| TCP | 3001-3004 | SG-ALB |

### SG-DATA (Ingreso desde APP)

| Protocolo | Puerto | Origen |
|---|---|---|
| TCP | 3306 | SG-APP |

---

## 4. AWS — EC2

| Instancia | Tipo | SO | Subred | Función |
|---|---|---|---|---|
| EC2 APP-1 | t4g.small (ARM Graviton) | Amazon Linux 2023 | Privada APP AZ1a | 5 contenedores Docker |
| EC2 APP-2 | t4g.small (ARM Graviton) | Amazon Linux 2023 | Privada APP AZ1b | 5 contenedores Docker |
| EC2 MySQL | t4g.small (ARM Graviton) | Amazon Linux 2023 | Privada DATA AZ1a | MySQL 8.0 |

**Configuración User Data EC2 APP** (`scripts/user-data-ec2.sh`):
- Actualiza SO, instala Docker
- Instala Docker Compose v2.29.2 (aarch64)
- Instala telnet y mysql client
- Agrega ec2-user al grupo docker

**Configuración MySQL EC2** (`scripts/user-data-ec2.sh`):
- Instala MySQL server
- Ejecuta `init.sql` para crear BD y datos iniciales
- Cifrado EBS habilitado

---

## 5. AWS — ECR (Elastic Container Registry)

5 repositorios, imágenes construidas para `linux/arm64`:

| Repositorio | Contenedor | Puerto |
|---|---|---|
| `freshbox-frontend` | nginx:alpine | 80 |
| `freshbox-get-products` | node:18-alpine | 3001 |
| `freshbox-create-product` | node:18-alpine | 3002 |
| `freshbox-update-product` | node:18-alpine | 3003 |
| `freshbox-delete-product` | node:18-alpine | 3004 |

---

## 6. AWS — ALB (Application Load Balancer)

| Parámetro | Valor |
|---|---|
| Tipo | Internet-facing |
| Subredes | Públicas AZ1a y AZ1b |
| Security Group | SG-ALB |
| Target Group | HTTP Puerto 80, ambas EC2 APP |
| Health Check | `GET /` en puerto 80 |
| Healthy threshold | 2 |
| Unhealthy threshold | 3 |

---

## 7. AWS — Backup

| Parámetro | Valor |
|---|---|
| Recurso | EC2 MySQL |
| Frecuencia | Diaria |
| Retención | 7 días |

---

## 8. Contenedores Docker (por instancia APP)

Cada EC2 APP ejecuta los 5 contenedores en la red `freshbox-net` (bridge):

### 8.1 Frontend (`freshbox-frontend`)

| Campo | Valor |
|---|---|
| Imagen base | `nginx:alpine` |
| Puerto expuesto | 80 |
| Archivos | `index.html`, `css/styles.css`, `js/app.js` |
| Configuración | `nginx.conf` — reverse proxy a microservicios |

**Nginx reverse proxy** (`microservicioFrontend/nginx.conf`):

| Ruta | Método | Proxy a |
|---|---|---|
| `/` | GET | Archivos estáticos |
| `/api/products` | GET | `http://get-products:3001` |
| `/api/products` | POST | `http://create-product:3002` |
| `/api/products/:id` | PUT | `http://update-product:3003` |
| `/api/products/:id` | DELETE | `http://delete-product:3004` |

### 8.2 get-products (`freshbox-get-products`)

| Campo | Valor |
|---|---|
| Imagen base | `node:18-alpine` |
| Puerto | 3001 |
| Framework | Express.js |
| Dependencias | express, mysql2, cors |
| Endpoints | `GET /api/products`, `GET /api/products/:id`, `GET /health` |

### 8.3 create-product (`freshbox-create-product`)

| Campo | Valor |
|---|---|
| Imagen base | `node:18-alpine` |
| Puerto | 3002 |
| Framework | Express.js |
| Dependencias | express, mysql2, cors |
| Endpoints | `POST /api/products`, `GET /health` |

### 8.4 update-product (`freshbox-update-product`)

| Campo | Valor |
|---|---|
| Imagen base | `node:18-alpine` |
| Puerto | 3003 |
| Framework | Express.js |
| Dependencias | express, mysql2, cors |
| Endpoints | `PUT /api/products/:id`, `GET /health` |

### 8.5 delete-product (`freshbox-delete-product`)

| Campo | Valor |
|---|---|
| Imagen base | `node:18-alpine` |
| Puerto | 3004 |
| Framework | Express.js |
| Dependencias | express, mysql2, cors |
| Endpoints | `DELETE /api/products/:id`, `GET /health` |

---

## 9. Base de Datos

**Motor:** MySQL 8.0

| Parámetro | Valor |
|---|---|
| Base de datos | `freshbox` |
| Usuario | `alumno` |
| Password | `alumno123` |
| Puerto | 3306 |
| Host local | `db` (docker-compose) |
| Host AWS | IP privada EC2 MySQL |

### Tabla `productos`

| Columna | Tipo | Descripción |
|---|---|---|
| `id` | INT, AUTO_INCREMENT, PK | Identificador |
| `nombre` | VARCHAR(255), NOT NULL | Nombre del producto |
| `descripcion` | TEXT | Descripción |
| `precio` | DECIMAL(10,2), NOT NULL | Precio en CLP |
| `stock` | INT, DEFAULT 0 | Stock disponible |
| `categoria` | VARCHAR(100) | Categoría |
| `imagen_url` | VARCHAR(500) | URL de imagen |
| `created_at` | TIMESTAMP | Fecha creación |
| `updated_at` | TIMESTAMP | Última actualización |

---

## 10. Variables de Entorno

| Variable | Contenedores Backend | Local (docker-compose) | AWS |
|---|---|---|---|
| `DB_HOST` | Todos los backend | `db` | IP privada EC2 MySQL |
| `DB_USER` | Todos los backend | `alumno` | `alumno` |
| `DB_PASS` | Todos los backend | `alumno123` | `alumno123` |
| `DB_NAME` | Todos los backend | `freshbox` | `freshbox` |
| `DB_PORT` | Todos los backend | `3306` | `3306` |
| `PORT` | Cada backend | 3001-3004 | 3001-3004 |

---

## 11. Scripts de Despliegue

### `scripts/ecr-push.sh`
Ejecutar desde PC local. Construye imágenes ARM64, crea repos ECR, pushea cada imagen.

### `scripts/deploy-containers.sh`
Ejecutar dentro de cada EC2 APP via Session Manager. Login ECR, pull de imágenes, red `freshbox-net`, run de los 5 contenedores.

### `scripts/user-data-ec2.sh`
User data para EC2 APP. Instala Docker, Docker Compose, herramientas de red.

---

## 12. Docker Compose (Prueba Local)

```bash
cd desarrolloappEP1/
docker compose build
docker compose up -d
docker compose ps
```

| Servicio | Puerto Local |
|---|---|
| Frontend | `http://localhost:8080` |
| get-products | `http://localhost:3001/api/products` |
| create-product | `http://localhost:3002/api/products` |
| update-product | `http://localhost:3003/api/products` |
| delete-product | `http://localhost:3004/api/products` |
| MySQL | `localhost:3306` |

---

## 13. Endpoints API

| Método | Endpoint | Servicio | Descripción |
|---|---|---|---|
| `GET` | `/api/products` | get-products | Listar todos los productos |
| `GET` | `/api/products/:id` | get-products | Obtener un producto por ID |
| `POST` | `/api/products` | create-product | Crear un producto nuevo |
| `PUT` | `/api/products/:id` | update-product | Modificar un producto existente |
| `DELETE` | `/api/products/:id` | delete-product | Eliminar un producto |
| `GET` | `/health` | Todos los backend | Health check de cada servicio |

---

## 14. Seguridad — Consideraciones

- **Credenciales hardcodeadas:** `root123`, `alumno123` presentes en `docker-compose.yml` e `index.js`. Migrar a AWS Secrets Manager o variables de entorno protegidas.
- **CORS:** Habilitado globalmente sin restricciones de origen en todos los microservicios.
- **SQL Injection:** Se utiliza `execute()` con parámetros de MySQL2 (protección parametrizada).
- **EBS:** Cifrado habilitado en EC2 APP y DATA.
- **Security Groups:** Encadenados ALB → APP → DATA (mínimo privilegio).

---

## 15. Estructura de Archivos

```
desarrolloappEP1/
├── README.md
├── docker-compose.yml
├── init.sql
├── microservicioFrontend/
│   ├── Dockerfile
│   ├── nginx.conf
│   ├── index.html
│   ├── css/styles.css
│   └── js/app.js
├── microserviciosBackend/
│   ├── get-products/      (Dockerfile, package.json, index.js)
│   ├── create-product/    (Dockerfile, package.json, index.js)
│   ├── update-product/    (Dockerfile, package.json, index.js)
│   └── delete-product/    (Dockerfile, package.json, index.js)
└── scripts/
    ├── user-data-ec2.sh
    ├── ecr-push.sh
    ├── deploy-containers.sh
    └── guia-docente-ep1.md
```
