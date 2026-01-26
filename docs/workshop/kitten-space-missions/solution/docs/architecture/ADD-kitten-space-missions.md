# Architecture Design Document (ADD)

## Kitten Space Missions API - Azure Cloud Solution

**Versión**: 1.0.0  
**Fecha**: 21 de enero de 2026  
**Entorno**: Development  
**Estado**: 📋 Propuesta para revisión

---

## 1. RESUMEN EJECUTIVO

### Objetivo
Diseñar e implementar una API REST completa para gestión de misiones espaciales tripuladas por astronautas gatunos, con arquitectura cloud-native en Azure, seguridad Zero Trust, y compliance con Well-Architected Framework.

### Alcance
- **Cliente**: MeowTech Space Agency
- **Proyecto**: Kitten Space Missions API
- **Entorno**: Development (westeurope)
- **Usuarios**: ~10-50 usuarios concurrentes inicialmente
- **Budget**: $50-100/mes en dev

### Impacto Esperado
✅ API REST completamente funcional con endpoints CRUD  
✅ Observabilidad completa con Application Insights  
✅ Seguridad Zero Trust con Private Endpoints  
✅ Auto-scaling automático (1-3 instancias)  
✅ Managed Identity (sin secretos en código)  
✅ Tiempo de respuesta p95 < 200ms  

---

## 2. CONTEXTO & REQUISITOS

### 2.1 Estado Actual
**Sistema Actual**: None (greenfield project)  
**Pain Points**: N/A (nuevo proyecto)  
**Baseline Metrics**: N/A

### 2.2 Requisitos Funcionales (FR)

| ID | Requisito | Descripción |
|----|-----------|-------------|
| FR-01 | CRUD Misiones | Create, Read, Update, Delete de misiones espaciales |
| FR-02 | CRUD Astronautas | Gestión de astronautas felinos asignados |
| FR-03 | Telemetría RT | Endpoint para recibir datos telemetría en tiempo real |
| FR-04 | Health Checks | Endpoint `/health` para monitoring y load balancer |
| FR-05 | Paginación | Soporte para paginación en listados (top, skip) |
| FR-06 | Filtrado | Filtros por estado de misión, astronauta, fecha |

### 2.3 Requisitos No Funcionales (NFR)

| Categoría | Requisito | Target |
|-----------|-----------|--------|
| **Performance** | Latencia p95 GET | < 200ms |
| **Performance** | Latencia p95 POST/PUT | < 500ms |
| **Availability** | Uptime en dev | 99% |
| **Security** | TLS mínimo | 1.2 |
| **Security** | Protocolo | HTTPS only |
| **Scalability** | Auto-scale instances | 1-3 (dev) |
| **Logging** | Retention días | 30 días (dev) |
| **Auth** | Framework | OAuth2 + Azure Entra ID |
| **Database** | Tipo | SQL relacional (Azure SQL) |
| **API Protocol** | Versioning | V1 (URL-based: /api/v1/) |

### 2.4 Constraints (Restricciones)

| Constraint | Detalle | Impacto |
|-----------|---------|--------|
| **Presupuesto** | $50-100/mes | SKUs básicos/económicos |
| **Sin DR** | Dev only, sin redundancia geo | Single region (westeurope) |
| **Compliance** | None | Proyecto educativo |
| **Equipo** | Solo .NET developers | No polyglot complexity |
| **Tenant** | Single Entra ID | Autenticación centralizada |

### 2.5 Dependencias Externas

- ✅ Azure Subscription: `cee1446f-17a4-40e0-865d-e1191eccb0bb`
- ✅ Entra ID Tenant: Disponible
- ✅ Repo GitHub: `azure-agent-pro` (Bicep modules)
- ✅ Access: Owner/Contributor role en subscription

---

## 3. ARQUITECTURA PROPUESTA

### 3.1 Diagrama High-Level (ASCII)

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET / CLIENTES                             │
└────────────────────────────────────────────┬─────────────────────────────────┘
                                             │ HTTPS (TLS 1.2+)
                                             │
                                      ┌──────┴──────┐
                                      │    Azure    │
                                      │  Front Door │ (optional: future CDN)
                                      │             │
                                      └──────┬──────┘
                                             │
                ┌────────────────────────────┼────────────────────────────┐
                │                                    VNet: 10.0.0.0/16    │
                │                                                         │
                │  ┌──────────────────────────────────────────────────┐  │
                │  │  PUBLIC SUBNET (snet-public-dev)                │  │
                │  │  10.0.1.0/24                                    │  │
                │  │                                                 │  │
                │  │   ┌────────────────────────────────────┐        │  │
                │  │   │  App Service Plan (Standard S1)    │        │  │
                │  │   │  - asp-kitten-missions-dev         │        │  │
                │  │   │  - AutoScale: 1-3 instances        │        │  │
                │  │   │  - Staging slot (blue-green)       │        │  │
                │  │   └────┬─────────────────────────────┬─┘        │  │
                │  │        │                             │          │  │
                │  │   ┌────▼───┐  ┌────────┐  ┌────────▼────┐     │  │
                │  │   │  API   │  │  API   │  │  API        │     │  │
                │  │   │ Inst-1 │  │ Inst-2 │  │  Inst-3     │     │  │
                │  │   │ (Pod)  │  │ (Pod)  │  │  (Pod)      │     │  │
                │  │   └────────┘  └────────┘  └─────────────┘     │  │
                │  │                                                 │  │
                │  │        ┌──────────────────────────┐             │  │
                │  │        │ Managed Identity        │             │  │
                │  │        │ (no passwords in code)   │             │  │
                │  │        └──────────────────────────┘             │  │
                │  └──────────────────────────────────────────────────┘  │
                │                          │                             │
                │                          │ (Private connection)        │
                │                          │                             │
                │  ┌──────────────────────┴──────────────────────────┐  │
                │  │  PRIVATE SUBNET (snet-private-dev)             │  │
                │  │  10.0.2.0/24                                   │  │
                │  │                                                │  │
                │  │   ┌──────────────────────────────────────┐     │  │
                │  │   │ Private Endpoint - SQL Database      │     │  │
                │  │   │ (SQL Connection only through here)   │     │  │
                │  │   └────────┬─────────────────────────────┘     │  │
                │  │            │                                    │  │
                │  │   ┌────────▼──────────────────────────────┐    │  │
                │  │   │  Azure SQL Database Server           │    │  │
                │  │   │  - sql-kitten-missions-dev           │    │  │
                │  │   │  - DB: dbkittendev                   │    │  │
                │  │   │  - SKU: Standard S0 (10 DTU)         │    │  │
                │  │   │  - TDE enabled, Firewall private     │    │  │
                │  │   │  - 7-day automatic backup            │    │  │
                │  │   └────────────────────────────────────┬─┘    │  │
                │  │                                        │      │  │
                │  │   ┌────────────────────────────────────▼──┐   │  │
                │  │   │ Private Endpoint - Key Vault         │   │  │
                │  │   │ (Secrets access only through here)   │   │  │
                │  │   └────────────────────────────────────┬──┘   │  │
                │  │                                        │      │  │
                │  │   ┌────────────────────────────────────▼──┐   │  │
                │  │   │ Private Endpoint - Storage Account   │   │  │
                │  │   │ (Logs/Backups only through here)     │   │  │
                │  │   └────────────────────────────────────────┘   │  │
                │  └──────────────────────────────────────────────────┘  │
                │                                                         │
                │  ┌─────────────────────────────────────────────────┐   │
                │  │ MONITORING & SECURITY RESOURCES                 │   │
                │  │                                                 │   │
                │  │  • Key Vault (kv-kitten-missions-dev)          │   │
                │  │  • Application Insights (appi-...)             │   │
                │  │  • Log Analytics Workspace (log-...)           │   │
                │  │  • Storage Account (stkiltendev)               │   │
                │  │  • Network Security Groups (NSGs)              │   │
                │  └─────────────────────────────────────────────────┘   │
                │                                                         │
                └─────────────────────────────────────────────────────────┘
                           │                          │
           ┌───────────────┴─────────┐  ┌────────────┴──────────┐
           │                         │  │                       │
       ┌───▼──────────┐       ┌──────▼──▼──────┐      ┌─────────▼────┐
       │ Azure Entra  │       │  Azure Entra   │      │  GitHub Repo │
       │  ID (OAuth2) │       │  ID (RBAC/MI)  │      │  (Bicep IaC) │
       └──────────────┘       └────────────────┘      └──────────────┘
```

### 3.2 Componentes Principales

#### 3.2.1 **Networking Layer**
- **VNet**: `vnet-kitten-missions-dev` (10.0.0.0/16)
- **Public Subnet**: `snet-public-dev` (10.0.1.0/24) - App Service
- **Private Subnet**: `snet-private-dev` (10.0.2.0/24) - SQL + Private Endpoint
- **NSG Rules**: 
  - Public: Allow HTTPS inbound, deny others
  - Private: Allow SQL port 1433 only from App Service

#### 3.2.2 **Compute Layer**
- **Azure App Service**:
  - Plan: `asp-kitten-missions-dev` (Standard S1, Linux)
  - App: `app-kitten-missions-dev`
  - Runtime: .NET 8 LTS
  - Identity: System-Assigned Managed Identity
  - Auto-scale: Min 1, Max 3 instances
  - Staging slot for blue-green deployments
  - HTTPS only, TLS 1.2+

#### 3.2.3 **Data Layer**
- **Azure SQL Database**:
  - Server: `sql-kitten-missions-dev`
  - Database: `dbkittendev`
  - SKU: Standard S0 (Basic compute)
  - Edition: Standard
  - Firewall: Private Endpoint only (no public IP)
  - Backup: 7 days retention (default)
  - Encryption: TDE enabled by default

#### 3.2.4 **Security Layer**
- **Key Vault**: `kv-kitten-missions-dev`
  - Secrets: Connection string (fallback), API keys
  - Private Endpoint enabled
  - RBAC: Managed Identity has reader access
  
- **Network Security**:
  - Private Endpoint for SQL
  - Private Endpoint for Key Vault
  - NSG micro-segmentation
  - No public IPs for database

#### 3.2.5 **Observability Layer**
- **Application Insights**: `appi-kitten-missions-dev`
  - Monitoring: Requests, dependencies, exceptions
  - Custom metrics for business events
  - Distributed tracing
  
- **Log Analytics Workspace**: `log-kitten-missions-dev`
  - Storage: 30 days retention
  - Query capabilities for diagnostics
  
- **Storage Account**: `stkiltendev` (for logs, backups)
  - Blob storage for long-term logs
  - Private Endpoint enabled

#### 3.2.6 **Identity & Access**
- **Azure Entra ID**:
  - OAuth2 provider
  - Application Registration for API
  - User groups for RBAC
  
- **RBAC Roles**:
  - `Contributor`: Deployment (CI/CD service principal)
  - `Reader`: Monitoring agents
  - `Key Vault Secrets User`: App Service → Key Vault

### 3.3 Data Flow

```
Client Request
    ↓ (HTTPS TLS 1.2+)
App Service (Managed Identity)
    ↓ (Authenticate with Entra ID)
App Service validates token
    ↓
Business Logic (.NET 8)
    ↓ (Query/Mutation)
Private Endpoint → SQL Database
    ↓ (Managed Identity auth, no password)
Azure SQL (TDE encrypted)
    ↓ (Query result)
Response ← App Service
    ↓
Logging → Application Insights
Logging → Log Analytics
Metrics → Monitor
    ↓
Client Response (HTTPS)
```

### 3.4 Authentication Flow (OAuth2 + Entra ID)

```
┌─────────────────────────────────────────────────────────┐
│                    CLIENT APPLICATION                   │
└───────────────────┬─────────────────────────────────────┘
                    │
                    ├─ 1. Redirect to /authorize
                    │
        ┌───────────▼──────────────┐
        │   Azure Entra ID Login   │
        │   (oauth2/v2.0/authorize)│
        │   (Managed by Microsoft) │
        └───────────┬──────────────┘
                    │
                    ├─ 2. User authenticates
                    │
        ┌───────────▼──────────────┐
        │  Entra ID Issues Token   │
        │  (JWT with claims)       │
        └───────────┬──────────────┘
                    │
                    ├─ 3. Authorization Code → App Service
                    │
        ┌───────────▼──────────────┐
        │   App Service Validates  │
        │   Token Signature        │
        │   Checks Scopes/Claims   │
        └───────────┬──────────────┘
                    │
                    ├─ 4. Bearer Token Valid → Request OK
                    │    Bearer Token Invalid → 401 Unauthorized
                    │
        ┌───────────▼──────────────┐
        │  Execute API Endpoint    │
        │  with User Context       │
        └───────────┬──────────────┘
                    │
                    ├─ 5. Response (200, 401, 403, etc)
                    │
        └───────────▼──────────────┐
                    Client
```

---

## 4. ARQUITECTURA WELL-ARCHITECTED (5 Pilares)

### 4.1 RELIABILITY (Confiabilidad)

✅ **Availability Zones**: Single region (westeurope) OK para dev  
✅ **Auto-Scaling**: 1-3 instances para handle spikes  
✅ **Health Probes**: App Service health check endpoint `/health`  
✅ **Backup**: 7 days SQL retention (default Standard edition)  
✅ **Error Handling**: Structured logging de todas las excepciones  
✅ **Resilience**: Retry logic con exponential backoff para errores transitorios  
✅ **Circuit Breaker**: Protección contra cascadas de errores  

**Resilience Patterns Implementados**:
- **Retry Policy**: 4 intentos con exponential backoff (100ms → 800ms)
- **Circuit Breaker**: Abre después de 3 fallos, recupera en 30 segundos
- **Timeout Protection**: Request timeout 30 segundos
- **Transient Error Detection**: Identifica automáticamente errores recuperables

⚠️ **Trade-offs**:
- No multi-region redundancy (acceptable en dev)
- RTO: ~5 minutos (App Service restart)
- RPO: ~1 hora (database point-in-time restore)
- Max retry latency: ~1.5 segundos por request (4 intentos + exponential backoff)

### 4.2 SECURITY (Seguridad)

✅ **Zero Trust Network**: Private Endpoints for SQL & KV  
✅ **HTTPS Only**: TLS 1.2+ enforcement  
✅ **Managed Identity**: No hardcoded passwords/secrets  
✅ **RBAC Least Privilege**: Custom roles por función  
✅ **Key Vault**: Centralized secrets management  
✅ **Encryption at Rest**: TDE enabled on SQL  
✅ **Encryption in Transit**: TLS 1.2+ + HTTPS  
✅ **Audit Logging**: All access logged to Log Analytics  
✅ **Network Segmentation**: NSG rules per subnet  

✅ **OAuth2 + Entra ID**: Industry-standard authentication  
✅ **No Public Endpoints**: SQL, KV behind Private Endpoints  

### 4.3 COST OPTIMIZATION (FinOps)

💰 **Estimated Monthly Cost**: **$65-75/mes**

| Resource | SKU | Qty | Cost/mes |
|----------|-----|-----|----------|
| App Service Plan | Standard S1 | 1 | $34.80 |
| Azure SQL | Standard S0 | 1 | $15.00 |
| Key Vault | Standard | 1 | $0.34 |
| App Insights | Basic | 1 | $2.91 |
| Log Analytics | Pay-As-You-Go | 1 | $2.00-5.00 |
| Storage Account | Standard LRS | 1 | $0.50 |
| VNet/NSG | N/A | 1 | FREE |
| Private Endpoints | 3x | 3 | $0.78 |
| **TOTAL** | | | **~$56-60/mes** |

✅ **Cost Optimization Opportunities**:
1. **Auto-shutdown dev** (outside business hours): -$15/mes
2. **Reserved Instance** (1-year): -30% = -$10/mes (if permanent)
3. **Spot VMs** (not applicable for App Service)

⚠️ **Cost Drivers**:
- App Service Standard (mandatory for auto-scale, staging slot)
- Private Endpoints: $0.26 each × 3 = $0.78/mes

✅ **Monitoring**: Budget alerts configured at $80/mes

### 4.4 OPERATIONAL EXCELLENCE (DevOps)

✅ **Infrastructure as Code**: 100% Bicep (modular)  
✅ **GitOps**: GitHub Actions CI/CD  
✅ **Blue-Green Deployment**: App Service staging slot  
✅ **Automated Testing**: Pre-deployment validation  
✅ **Monitoring Dashboards**: Azure Monitor + Workbooks  
✅ **Alerting**: Automated incident notifications  
✅ **Runbooks**: Deployment guides documented  
✅ **Change Management**: PR-based approvals  

⚡ **Deployment Pipeline**:
```
1. Developer pushes to feature branch
2. GitHub Actions: Build + Unit tests + SAST scan
3. Merge to main triggers deployment
4. What-If preview (human approval required)
5. Blue-Green deploy to staging
6. Smoke tests on staging
7. Traffic switch to production (98% → 100%)
8. Rollback available (staging still has old version)
```

### 4.5 PERFORMANCE EFFICIENCY (Rendimiento)

#### Auto-Scaling Strategy

✅ **Auto-Scaling**: Min 1 → Max 3 instances  

**Políticas de Scale-Up (Aumentar Instancias)**:
- **Metric**: CPU Percentage
- **Threshold**: > 70% CPU
- **Duration**: 5 minutos sostenido
- **Action**: Agregar 1 instancia
- **Max Instances**: 3
- **Cooldown**: 5 minutos (evitar scaling thrashing)

**Políticas de Scale-Down (Reducir Instancias)**:
- **Metric**: CPU Percentage
- **Threshold**: < 30% CPU
- **Duration**: 15 minutos sostenido
- **Action**: Remover 1 instancia
- **Min Instances**: 1
- **Cooldown**: 10 minutos (prevenir fluctuaciones)

**Lógica de Escalado**:
```
Estado: 1 instancia (inicial)
↓ (CPU > 70% por 5 min)
→ Escalar a 2 instancias
↓ (CPU > 70% por 5 min)
→ Escalar a 3 instancias (MÁXIMO)
↓ (CPU < 30% por 15 min)
→ Reducir a 2 instancias
↓ (CPU < 30% por 15 min)
→ Reducir a 1 instancia (MÍNIMO)
```

#### Resilience & Retry Strategy

✅ **Retry Logic para Errores Transitorios**:

**Errores Elegibles para Retry**:
- Timeout en conexiones SQL (< 2 min)
- Errores 429 (Rate Limiting)
- Errores 503 (Service Unavailable)
- Errores 504 (Gateway Timeout)
- Transient network errors

**Errores NO Elegibles** (fallan inmediatamente):
- 400 (Bad Request)
- 401 (Unauthorized)
- 403 (Forbidden)
- 404 (Not Found)
- Errores de validación de datos

**Política de Retry**:
```
Intento 1: Inmediato
  ↓ FALLA (error transitorio)
Espera: 100ms (exponential backoff)
Intento 2: 100ms después
  ↓ FALLA
Espera: 200ms × 2 (exponential)
Intento 3: 200ms después
  ↓ FALLA
Espera: 400ms × 2 (exponential)
Intento 4: 400ms después
  ↓ FALLA (máximo 4 intentos)
Error Final: 503 Service Unavailable (al cliente)
```

**Implementación en .NET con Polly**:
```csharp
// Usar Polly library para retry resilience
var retryPolicy = Policy
    .Handle<SqlException>()
    .Or<HttpRequestException>()
    .Or<OperationCanceledException>()
    .WaitAndRetryAsync(
        retryCount: 4,
        sleepDurationProvider: attempt => 
            TimeSpan.FromMilliseconds(Math.Pow(2, attempt) * 100),
        onRetry: (outcome, timespan, retryCount, context) =>
        {
            logger.LogWarning(
                $"Retry {retryCount} after {timespan.TotalMilliseconds}ms");
        });

// Usar con Circuit Breaker para proteger DB
var circuitBreakerPolicy = Policy
    .Handle<SqlException>()
    .CircuitBreakerAsync(
        handledEventsAllowedBeforeBreaking: 3,
        durationOfBreak: TimeSpan.FromSeconds(30),
        onBreak: (outcome, timespan) =>
        {
            logger.LogError($"Circuit breaker opened for {timespan.TotalSeconds}s");
        });

// Combinar políticas
var resilientPolicy = Policy.WrapAsync(retryPolicy, circuitBreakerPolicy);
```

**Configuración en appsettings.json**:
```json
{
  "Resilience": {
    "MaxRetryAttempts": 4,
    "InitialDelayMs": 100,
    "CircuitBreakerThreshold": 3,
    "CircuitBreakerTimeoutSeconds": 30,
    "RequestTimeoutSeconds": 30
  }
}
```

**Monitoreo de Retries**:
- Contar retry attempts en Application Insights
- Alertar si retry rate > 5% de requests
- Investigar causas raíz de errores transitorios
- Dashboard métrica: "Retry Success Rate" (target > 90%)

#### Caching & Optimization

✅ **Caching**: In-memory caching for frequently accessed data  
✅ **Database Indexing**: Strategic indexes on FK + search columns  
✅ **Async Processing**: Long-running tasks with Service Bus (future)  
✅ **Load Testing**: Baseline at 50 concurrent users  

📊 **SLOs (Service Level Objectives)**:
- **Latency p95**: < 200ms (GET)
- **Latency p95**: < 500ms (POST/PUT)
- **Availability**: 99.0% (dev)
- **Error Rate**: < 0.1%
- **Retry Success Rate**: > 90%

---

## 5. DISEÑO DE DATOS - SCHEMA SQL

### 5.1 Entity-Relationship Diagram (ASCII)

```
┌──────────────────┐          ┌─────────────────┐
│   Astronauts     │ 1      * │    Missions     │
│                  │◄────────►│                 │
│  - Id (PK)       │ assigned │  - Id (PK)      │
│  - Name          │          │  - Name         │
│  - CallSign      │          │  - Status       │
│  - Email         │          │  - LaunchDate   │
│  - Status        │          │  - Target       │
│  - CreatedAt     │          │  - CreatedAt    │
│  - UpdatedAt     │          │  - UpdatedAt    │
└──────────────────┘          └─────┬───────────┘
                                    │
                                    │ 1
                                    │
                              ┌─────▼──────────┐
                              │   Telemetry    │
                              │                │
                              │  - Id (PK)     │
                              │  - MissionId   │
                              │  - Timestamp   │
                              │  - Altitude    │
                              │  - Speed       │
                              │  - Status      │
                              │  - RawData     │
                              └────────────────┘
```

### 5.2 Schema SQL Detallado

```sql
-- ============================================================
-- ASTRONAUTS TABLE
-- ============================================================
CREATE TABLE dbo.Astronauts (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    Name NVARCHAR(100) NOT NULL,
    CallSign NVARCHAR(50) NOT NULL UNIQUE,
    Email NVARCHAR(100) NOT NULL UNIQUE,
    Status NVARCHAR(20) NOT NULL DEFAULT 'Active'  -- Active, Inactive, OnMission
    CHECK (Status IN ('Active', 'Inactive', 'OnMission')),
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    
    INDEX IX_Astronauts_Status NONCLUSTERED (Status),
    INDEX IX_Astronauts_Email NONCLUSTERED (Email)
);

-- ============================================================
-- MISSIONS TABLE
-- ============================================================
CREATE TABLE dbo.Missions (
    Id UNIQUEIDENTIFIER PRIMARY KEY DEFAULT NEWID(),
    Name NVARCHAR(200) NOT NULL,
    Description NVARCHAR(MAX),
    Status NVARCHAR(20) NOT NULL DEFAULT 'Planned'
    CHECK (Status IN ('Planned', 'Active', 'Completed', 'Aborted')),
    Target NVARCHAR(100) NOT NULL,  -- e.g., 'Moon', 'Mars', 'ISS'
    LaunchDate DATETIME2 NOT NULL,
    LandingDate DATETIME2,
    CommanderId UNIQUEIDENTIFIER NOT NULL,
    Duration INT,  -- minutes
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    UpdatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    
    FOREIGN KEY (CommanderId) REFERENCES dbo.Astronauts(Id),
    INDEX IX_Missions_Status NONCLUSTERED (Status),
    INDEX IX_Missions_LaunchDate NONCLUSTERED (LaunchDate),
    INDEX IX_Missions_CommanderId NONCLUSTERED (CommanderId)
);

-- ============================================================
-- MISSION_CREW JUNCTION TABLE (Many-to-Many)
-- ============================================================
CREATE TABLE dbo.MissionCrew (
    MissionId UNIQUEIDENTIFIER NOT NULL,
    AstronautId UNIQUEIDENTIFIER NOT NULL,
    Role NVARCHAR(50) NOT NULL,  -- 'Commander', 'Pilot', 'Specialist'
    AssignedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    
    PRIMARY KEY (MissionId, AstronautId),
    FOREIGN KEY (MissionId) REFERENCES dbo.Missions(Id) ON DELETE CASCADE,
    FOREIGN KEY (AstronautId) REFERENCES dbo.Astronauts(Id),
    INDEX IX_MissionCrew_AstronautId NONCLUSTERED (AstronautId)
);

-- ============================================================
-- TELEMETRY TABLE (Time-series data)
-- ============================================================
CREATE TABLE dbo.Telemetry (
    Id BIGINT PRIMARY KEY IDENTITY(1,1),
    MissionId UNIQUEIDENTIFIER NOT NULL,
    Timestamp DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    Altitude FLOAT,  -- meters
    Speed FLOAT,  -- m/s
    Temperature FLOAT,  -- Celsius
    OxygenLevel FLOAT,  -- percentage
    SystemStatus NVARCHAR(50) NOT NULL DEFAULT 'Normal'
    CHECK (SystemStatus IN ('Normal', 'Warning', 'Critical')),
    RawData NVARCHAR(MAX),  -- JSON with extended data
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    
    FOREIGN KEY (MissionId) REFERENCES dbo.Missions(Id) ON DELETE CASCADE,
    INDEX IX_Telemetry_MissionId_Timestamp NONCLUSTERED (MissionId, Timestamp DESC),
    INDEX IX_Telemetry_Timestamp NONCLUSTERED (Timestamp DESC)
);

-- ============================================================
-- AUDIT_LOG TABLE (Compliance & debugging)
-- ============================================================
CREATE TABLE dbo.AuditLog (
    Id BIGINT PRIMARY KEY IDENTITY(1,1),
    EntityType NVARCHAR(50) NOT NULL,  -- 'Mission', 'Astronaut', 'Telemetry'
    EntityId UNIQUEIDENTIFIER,
    Action NVARCHAR(20) NOT NULL,  -- 'CREATE', 'UPDATE', 'DELETE', 'READ'
    ChangedBy NVARCHAR(200),  -- User principal
    OldValues NVARCHAR(MAX),  -- JSON before
    NewValues NVARCHAR(MAX),  -- JSON after
    IpAddress NVARCHAR(50),
    CreatedAt DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
    
    INDEX IX_AuditLog_EntityId NONCLUSTERED (EntityId),
    INDEX IX_AuditLog_CreatedAt NONCLUSTERED (CreatedAt DESC)
);

-- ============================================================
-- STORED PROCEDURE: Get active missions with crew
-- ============================================================
CREATE PROCEDURE usp_GetActiveMissionsWithCrew
    @Status NVARCHAR(20) = 'Active'
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        m.Id,
        m.Name,
        m.Status,
        m.Target,
        m.LaunchDate,
        m.CreatedAt,
        (SELECT 
            a.Id,
            a.Name,
            a.CallSign,
            mc.Role
         FROM dbo.MissionCrew mc
         JOIN dbo.Astronauts a ON mc.AstronautId = a.Id
         WHERE mc.MissionId = m.Id
         FOR JSON PATH) AS Crew
    FROM dbo.Missions m
    WHERE m.Status = @Status
    ORDER BY m.LaunchDate DESC;
END;
GO

-- ============================================================
-- INDEXES STRATEGY
-- ============================================================
/*
PRIMARY INDEXES:
- Astronauts(Id): Clustered on PK
- Missions(Id): Clustered on PK
- Telemetry(Id): Clustered on identity PK (for fast inserts)

SECONDARY INDEXES:
- Astronauts(Status): For filtering active astronauts
- Missions(Status, LaunchDate): Common filter + sort
- MissionCrew(AstronautId): For reverse lookups
- Telemetry(MissionId, Timestamp): Time-series queries
- AuditLog(CreatedAt): For recent audit entries

MAINTENANCE:
- Rebuild indexes monthly or when fragmentation > 30%
- Update statistics weekly
- Monitor index usage via DMVs
*/
```

### 5.3 Connection String Format

```csharp
// Development (Managed Identity - RECOMMENDED)
Server=tcp:sql-kitten-missions-dev.database.windows.net,1433;
Initial Catalog=dbkittendev;
Encrypt=true;
TrustServerCertificate=false;
Connection Timeout=30;
Authentication=Active Directory Default;

// Fallback (if MI fails - stored in Key Vault)
Server=tcp:sql-kitten-missions-dev.database.windows.net,1433;
Initial Catalog=dbkittendev;
User ID=sqladmin;
Password=<vault-secret>;
Encrypt=true;
TrustServerCertificate=false;
```

---

## 6. PLAN DE IMPLEMENTACIÓN

### 6.1 Estructura de Código Bicep

```
bicep/
├── main.bicep                          # Orquestador principal
├── modules/
│   ├── virtual-network.bicep           # VNet, subnets, NSGs
│   ├── app-service.bicep               # App Service Plan + App
│   ├── sql-database.bicep              # Azure SQL Database
│   ├── key-vault.bicep                 # Key Vault
│   ├── private-endpoint.bicep          # Private Endpoints
│   ├── monitoring.bicep                # App Insights + Log Analytics
│   └── storage-account.bicep           # Storage for logs
└── parameters/
    ├── dev.bicepparam                  # Parameters file (new format)
    ├── dev.parameters.json             # Fallback (legacy)
    ├── prod.bicepparam                 # Future production
    └── prod.parameters.json            # Future production
```

### 6.2 Phases de Implementación

#### **PHASE 1: Foundation (Week 1)**

**Objetivos**:
- [ ] Infrastructure base deployed
- [ ] Networking validated
- [ ] Database schema created

**Tareas**:
1. Create VNet, subnets, NSGs
2. Deploy SQL Server + Database
3. Create Key Vault
4. Configure Private Endpoints
5. Execute SQL schema scripts
6. Validate connectivity (bastion/vpn)

**Deliverables**:
- Bicep modules validated with `az bicep build`
- Network diagram confirmed
- SQL schema deployed

#### **PHASE 2: Application (Week 2)**

**Objetivos**:
- [ ] App Service deployed
- [ ] Managed Identity configured
- [ ] OAuth2 integration working
- [ ] API endpoints functional

**Tareas**:
1. Deploy App Service (staging slot)
2. Create System-Assigned Managed Identity
3. Register app in Entra ID
4. Configure RBAC (MI → SQL, MI → KV)
5. Deploy .NET 8 API code (reference)
6. Configure connection strings via KV
7. Enable diagnostics logging

**Deliverables**:
- API running on staging slot
- Health endpoint responding
- Logs flowing to Application Insights

#### **PHASE 3: Monitoring & Hardening (Week 3)**

**Objetivos**:
- [ ] Full observability enabled
- [ ] Security checklist 100%
- [ ] Load testing completed
- [ ] Production-ready

**Tareas**:
1. Configure alerts (latency, errors, availability)
2. Create dashboards
3. Perform security scan (Defender for Cloud)
4. Load test (50 concurrent users)
5. Failover test (manual)
6. Documentation completed
7. Runbook creation

**Deliverables**:
- SLO monitoring dashboard
- Security assessment passed
- Load test report (p95 latencies)
- Runbooks for ops team

### 6.3 Timeline Gantt (ASCII)

```
PHASE 1: Foundation          [████████]
  ├─ VNet & Networking       [████]
  ├─ SQL Database Setup       [    ████]
  └─ KV & Private Endpoints   [      ██]

PHASE 2: Application         [        ████████]
  ├─ App Service Deploy       [        ██]
  ├─ Managed Identity RBAC    [          ████]
  └─ API Code + Health        [            ██]

PHASE 3: Hardening          [              ████████]
  ├─ Monitoring Setup         [              ██]
  ├─ Security Hardening       [                ████]
  └─ Load Testing + Docs      [                  ██]

Week:                         1    2    3    4
```

---

## 7. TABLA DE RECURSOS AZURE (SKUs + Costos)

### 7.1 Production Resources - Desarrollo

| # | Recurso | Tipo | SKU | Cantidad | Costo/mes | Notas |
|---|---------|------|-----|----------|-----------|-------|
| 1 | Virtual Network | Networking | Standard | 1 | FREE | 10.0.0.0/16 |
| 2 | Network Security Group (Public) | Networking | Standard | 1 | FREE | snet-public |
| 3 | Network Security Group (Private) | Networking | Standard | 1 | FREE | snet-private |
| 4 | App Service Plan | Compute | Standard S1 | 1 | **$34.80** | Linux, autoscale 1-3 |
| 5 | App Service | Compute | (included) | 1 | (included) | app-kitten-missions-dev |
| 6 | App Service Staging Slot | Compute | (included) | 1 | (included) | Blue-green deployment |
| 7 | Azure SQL Server | Database | Free | 1 | FREE | Firewall rules |
| 8 | Azure SQL Database | Database | Standard S0 | 1 | **$15.00** | 10 DTU, 250GB storage |
| 9 | SQL Database Backup | Backup | LRS 7 days | 1 | (included) | Default retention |
| 10 | Key Vault | Security | Standard | 1 | **$0.34** | secrets, encryption keys |
| 11 | Application Insights | Monitoring | Basic/PAYG | 1 | **$2.91** | 5GB/month included |
| 12 | Log Analytics Workspace | Monitoring | PAYG | 1 | **$2.00-5.00** | 30-day retention |
| 13 | Storage Account | Storage | Standard LRS | 1 | **$0.50** | Logs + diagnostics |
| 14 | Private Endpoint (SQL) | Networking | - | 1 | **$0.26** | Daily charge |
| 15 | Private Endpoint (KV) | Networking | - | 1 | **$0.26** | Daily charge |
| 16 | Private Endpoint (Storage) | Networking | - | 1 | **$0.26** | Daily charge |
| | | | | **TOTAL** | **~$56-62/mes** | **🎯 PRESUPUESTO: $50-100/mes** ✅ |

### 7.2 Breakdown por Categoría

| Categoría | Subtotal | % del Budget |
|-----------|----------|--------------|
| **Compute** | $34.80 | 56% |
| **Database** | $15.00 | 24% |
| **Networking** | $0.78 | 1% |
| **Monitoring** | $5.91 | 9% |
| **Security** | $0.34 | 1% |
| **Storage** | $0.50 | 1% |
| **TOTAL** | **$57.33** | **92%** |

✅ **Status**: Dentro de presupuesto con margen de $2.67/mes

---

## 8. ESTRATEGIA DE BACKUP - AUTOMATIC BACKUP INCLUIDO

### 8.1 Automatic Backup (Incluido en SQL Standard S0)

La solución utiliza la estrategia de backup automático incluido en Azure SQL Database Standard S0:

```
✅ Incluido en SQL Standard S0 (Sin costo adicional)
✅ Retención automática: 7 días
✅ Tipos de backup:
   - 5 backups diarios (full)
   - 1 backup semanal (full)
   - 1 backup mensual (full)
✅ Point-in-time restore: Cualquier punto en los últimos 7 días
✅ RPO (Recovery Point Objective): 5-10 minutos
✅ RTO (Recovery Time Objective): 5-10 minutos
✅ Ubicación: Geo-redundant storage (automático)
✅ Costo: $0 (incluido en SKU Standard S0)
```

### 8.2 Restauración desde Backup

En caso de necesitar restaurar desde un backup:

```bash
# Restore a un punto específico en el tiempo (últimos 7 días)
az sql db restore \
  --resource-group "rg-kitten-missions-dev" \
  --server "sql-kitten-missions-dev" \
  --name "dbkittendev-restored" \
  --source-database "dbkittendev" \
  --point-in-time "2026-01-21T10:00:00Z"

# O renombrar para reemplazar la BD actual
# (después de validar en restore temporal)
```

### 8.3 Resumen: Backup Strategy para Dev

| Aspecto | Detalle |
|--------|--------|
| **Tipo** | Automatic Backup (Incluido) |
| **Retención** | 7 días automáticos |
| **RPO** | 5-10 minutos |
| **RTO** | 5-10 minutos |
| **Punto-in-time** | Sí, últimos 7 días |
| **Costo** | $0 (incluido en S0) |
| **Geo-redundancia** | Sí (automático) |
| **Restore Time** | < 10 minutos típicamente |
| **Apto para Dev** | ✅ Completamente suficiente |

✅ **Conclusión**: El automatic backup incluido es totalmente suficiente y recomendado para el entorno development. No se necesitan opciones adicionales.

---

## 9. CHECKLIST DE SEGURIDAD (Security Assessment)

### 9.1 Network Security

- [ ] VNet created with private subnets (10.0.0.0/16)
- [ ] NSG rules: Deny-all default, allow specific rules
- [ ] No public IPs for SQL Database ✅ (Private Endpoint)
- [ ] No public IPs for Key Vault ✅ (Private Endpoint)
- [ ] NSG rule: SQL port 1433 only from App Service subnet
- [ ] NSG rule: HTTPS 443 inbound on public subnet
- [ ] DDoS Standard protection (optional, not needed for dev)

### 9.2 Data Protection

- [ ] Azure SQL: Transparent Data Encryption (TDE) enabled by default
- [ ] Azure SQL: Firewall rules configured (private endpoint only)
- [ ] Azure SQL: Minimum TLS version 1.2 enforced
- [ ] Key Vault: Private endpoint enabled
- [ ] Key Vault: Network ACL: Deny-all, allow App Service
- [ ] Storage Account: HTTPS only, TLS 1.2+
- [ ] Connection strings in Key Vault (not in config files)
- [ ] Database encryption at rest (TDE) ✅
- [ ] Database encryption in transit (TLS) ✅

### 9.3 Identity & Access Management

- [ ] Managed Identity created for App Service
- [ ] RBAC role: "Key Vault Secrets User" assigned to MI
- [ ] RBAC role: "SQL DB Contributor" assigned to MI
- [ ] No hardcoded credentials anywhere
- [ ] No service principal passwords in code
- [ ] OAuth2 Entra ID configured for API
- [ ] User groups defined for RBAC
- [ ] MFA enforcement policy configured (Entra ID)
- [ ] Conditional Access rules created
- [ ] Service Principal: Least privilege roles only

### 9.4 Application Security

- [ ] HTTPS only, TLS 1.2+ minimum
- [ ] Application Insights enabled (logging all requests)
- [ ] Structured logging (not plaintext)
- [ ] Sensitive data redaction in logs
- [ ] API rate limiting configured (optional, tier-based)
- [ ] CORS policy configured (if SPA frontend)
- [ ] Input validation on all endpoints
- [ ] Output encoding to prevent XSS
- [ ] SQL parameterized queries (PREVENT SQL injection)
- [ ] CSRF tokens if applicable
- [ ] Security headers: HSTS, X-Content-Type-Options, etc.

### 9.5 Monitoring & Auditing

- [ ] Azure Defender for Cloud enabled
- [ ] All API calls logged to Application Insights
- [ ] All database access logged via audit table
- [ ] Audit logs stored in Log Analytics (30-day retention)
- [ ] Alerts configured for failed authentication
- [ ] Alerts configured for unusual activity
- [ ] Regular security assessments scheduled
- [ ] Vulnerability scanning enabled (Defender)
- [ ] Backup integrity tests scheduled

### 9.6 Compliance & Governance

- [ ] Azure Policy: Require encryption
- [ ] Azure Policy: Require HTTPS only
- [ ] Azure Policy: Require tags on all resources
- [ ] Tagging strategy implemented (Owner, CostCenter, Env, etc)
- [ ] Change management: PR-based approvals
- [ ] Infrastructure as Code versioning (Git)
- [ ] Security incidents runbook created
- [ ] Data retention policy defined (30 days dev)

### 9.7 Disaster Recovery

- [ ] Backup retention: 7 days (automatic)
- [ ] Backup testing: Restore from backup monthly
- [ ] RTO: 5-10 minutes documented
- [ ] RPO: 5-10 minutes documented
- [ ] Failover procedure documented
- [ ] Recovery runbook created
- [ ] No manual backups needed (automatic included)

### 9.8 Cost Control

- [ ] Budget alert set at $80/month
- [ ] Cost anomaly detection enabled
- [ ] Auto-shutdown enabled for non-prod
- [ ] Reserved instances evaluated (not yet)
- [ ] Orphaned resources cleanup scheduled
- [ ] Unused services auto-deprovisioned

---

## 10. VALIDACIÓN & TESTING

### 10.1 Pre-Deployment Checklist

- [ ] **Bicep Validation**
  ```bash
  az bicep build --file bicep/main.bicep
  az bicep build --file bicep/modules/virtual-network.bicep
  # etc... all modules
  ```

- [ ] **What-If Review**
  ```bash
  az deployment group create \
    --resource-group "rg-kitten-missions-dev" \
    --template-file bicep/main.bicep \
    --parameters bicep/parameters/dev.bicepparam \
    --what-if
  ```

- [ ] **Security Scanning**
  ```bash
  checkov -f bicep/main.bicep --framework bicep
  az security assessment list
  ```

- [ ] **Cost Estimation**
  ```
  Verify in Azure Pricing Calculator: $56-62/mes
  ```

- [ ] **Policy Compliance**
  ```bash
  az policy state list --filter "complianceState eq 'NonCompliant'"
  ```

### 10.2 Post-Deployment Testing

#### **Smoke Tests** (15 min)
```bash
✅ App Service responding on HTTPS
✅ Health endpoint: GET /health → 200
✅ Database connectivity: SQL test query succeeds
✅ Key Vault access: MI can read secrets
✅ Logs flowing to Application Insights
```

#### **Integration Tests** (30 min)
```bash
✅ OAuth2 login flow works
✅ CRUD endpoints functional (GET/POST/PUT/DELETE)
✅ Database transactions committed
✅ Managed Identity authentication (no password)
✅ Error handling returns proper HTTP status codes
```

#### **Security Tests** (20 min)
```bash
✅ HTTPS enforced (HTTP redirects to HTTPS)
✅ TLS 1.2 minimum enforced
✅ No SQL Database public IP
✅ Private Endpoint connection established
✅ Firewall rules restrict access
✅ Audit logging enabled
```

#### **Performance Tests** (30 min)
```
Load Test: 50 concurrent users, 5 min duration
- Latency p50: < 100ms ✅
- Latency p95: < 200ms ✅
- Latency p99: < 500ms ✅
- Error rate: < 0.1% ✅
- Availability: 99%+ ✅
```

#### **Failover Test** (20 min)
```bash
1. Record App Service instance count (N)
2. Manually stop 1 instance
3. Verify app still responding (N-1 instances)
4. Verify auto-scale spins up new instance
5. Confirm back to N instances
6. Record RTO: < 5 minutes ✅
```

---

## 11. SIGN-OFF & APPROVALS

| Role | Nombre | Fecha | Aprobado |
|------|--------|-------|----------|
| **Solution Architect** | Azure_Architect_Pro | TBD | ⏳ Pending Review |
| **Lead Developer** | [TBD] | TBD | ⏳ Pending Review |
| **Security Officer** | [TBD] | TBD | ⏳ Pending Review |
| **Budget Owner** | [MeowTech Finance] | TBD | ⏳ Pending Review |

---

## 12. ANEXOS

### A. Referencias & Documentación
- [Azure App Service Documentation](https://learn.microsoft.com/azure/app-service/)
- [Azure SQL Database Best Practices](https://learn.microsoft.com/azure/azure-sql/database/best-practices-and-considerations)
- [Azure Key Vault Security Best Practices](https://learn.microsoft.com/azure/key-vault/general/security-best-practices)
- [OAuth2 / OpenID Connect with Azure Entra ID](https://learn.microsoft.com/azure/active-directory/develop/v2-protocols)
- [Well-Architected Framework](https://learn.microsoft.com/azure/architecture/framework/)

### B. Términos de Acrónimos
- **ADD**: Architecture Design Document
- **MI**: Managed Identity
- **KV**: Key Vault
- **NSG**: Network Security Group
- **RBAC**: Role-Based Access Control
- **RTO**: Recovery Time Objective
- **RPO**: Recovery Point Objective
- **SLO**: Service Level Objective
- **DTU**: Database Transaction Unit
- **TDE**: Transparent Data Encryption
- **LTR**: Long-Term Retention
- **BACPAC**: SQL Database backup file format

### C. Próximos Pasos (After ADD Approval)

1. ✅ **ADD Review & Approval** (This document)
2. 📝 **Bicep Module Development** (Week 1-2)
3. 🔧 **Infrastructure Deployment** (Week 2-3)
4. 💻 **.NET API Development** (Parallel with infra)
5. 🧪 **Integrated Testing** (Week 3-4)
6. 📊 **Production Readiness Review** (Week 4)
7. 🚀 **Go-Live Decision**

---

**Documento preparado por**: Azure_Architect_Pro  
**Fecha**: 21 de enero de 2026  
**Versión**: 1.0.0 (Draft - Pending Approval)  
**Estado**: 🟡 **UNDER REVIEW** - Awaiting stakeholder approval
