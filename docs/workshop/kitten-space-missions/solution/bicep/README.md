# Kitten Space Missions API - Infrastructure as Code (Bicep)

## 📋 Descripción General

Este directorio contiene la infraestructura completa **Infrastructure as Code (IaC)** para la aplicación **Kitten Space Missions API** en Azure, implementada mediante **Bicep**.

**Características principales:**
- ✅ Arquitectura modular y reutilizable
- ✅ Multi-entorno (dev, test, prod) con parámetros específicos
- ✅ Seguridad por defecto (Managed Identity, RBAC, Private Endpoints)
- ✅ Observabilidad integrada (Log Analytics + Application Insights)
- ✅ Despliegue reproducible y idempotente

---

## 📁 Estructura de Archivos

```
bicep/
├── README.md                           # Este archivo
├── main.bicep                          # Orquestador principal (subscription scope)
├── modules/
│   ├── networking.bicep                # VNet, Subnets, NSG
│   ├── app-service.bicep               # App Service Plan + App Service
│   ├── sql-database.bicep              # SQL Server + Database
│   ├── key-vault.bicep                 # Key Vault con RBAC
│   ├── private-endpoint.bicep          # Private Endpoint genérico (reutilizable)
│   ├── monitoring.bicep                # Log Analytics + Application Insights
│   └── rbac.bicep                      # Role-Based Access Control assignments
└── parameters/
    ├── dev.parameters.json             # Parámetros para ambiente desarrollo
    └── prod.parameters.json            # Parámetros para ambiente producción
```

---

## 🔗 Diagrama de Dependencias de Módulos

```
                          ┌─────────────┐
                          │ main.bicep  │
                          └──────┬──────┘
                                 │
                    ┌────────────┼────────────┬──────────────┐
                    │            │            │              │
                    ▼            ▼            ▼              ▼
            ┌─────────────┐  ┌───────────┐  ┌──────────┐  ┌────────────┐
            │ networking  │  │ monitoring│  │key-vault │  │sql-database│
            │  (VNet)     │  │(Logs/AI)  │  │(Secrets) │  │ (SQL DB)   │
            └─────────────┘  └───────────┘  └──────────┘  └────────────┘
                    │              │            │              │
                    │              │            │              │
                    └──────────────┼────────────┴──┬───────────┘
                                   │               │
                                   ▼               ▼
                            ┌──────────────────────────────┐
                            │ private-endpoint (SQL)       │
                            │ & private-endpoint (KV)      │
                            └──────────────────────────────┘
                                   │
                    ┌──────────────┼──────────────┐
                    │              │              │
                    ▼              ▼              ▼
            ┌─────────────┐  ┌──────────┐  ┌────────┐
            │app-service  │  │rbac      │  │(DNS    │
            │(Web App)    │  │Permisos  │  │Zones)  │
            └─────────────┘  └──────────┘  └────────┘
                    │              │
                    └──────────────┴──────┐
                                         │
                                    ✅ COMPLETO
```

### 📋 Tabla de Dependencias

| Módulo | Depends On | Razón |
|--------|-----------|-------|
| **networking** | (ninguno) | Fundación de red |
| **monitoring** | (ninguno) | Log Analytics workspace independiente |
| **key-vault** | (ninguno) | No requiere dependencias externas |
| **sql-database** | monitoring | Diagnostic settings → Log Analytics |
| **private-endpoint (SQL)** | networking, sql-database | PE subnet + SQL Server ID |
| **private-endpoint (KV)** | networking, key-vault | PE subnet + Key Vault ID |
| **app-service** | networking, monitoring, key-vault, sql-database | VNet integration, logs, secrets, DB connection |
| **rbac** | app-service, sql-database, key-vault | Role assignments del Managed Identity |

### 🔄 Orden de Despliegue (Automático en main.bicep)

```
1️⃣  networking          ← Sin dependencias
2️⃣  monitoring          ← Sin dependencias
3️⃣  key-vault           ← Sin dependencias
4️⃣  sql-database        ← Depende de: monitoring
5️⃣  private-endpoint(SQL) ← Depende de: sql-database, networking
6️⃣  private-endpoint(KV)  ← Depende de: key-vault, networking
7️⃣  app-service        ← Depende de: TODOS los anteriores
8️⃣  rbac               ← Depende de: app-service, sql-database, key-vault
```

**Nota:** main.bicep maneja automáticamente el orden con `dependsOn` blocks. ✅

---

## 🏗️ Responsabilidad de Cada Módulo

### **main.bicep** (Orquestador Principal)
**Propósito:** Orquestar el despliegue de todos los módulos en el orden correcto.

**Scope:** `subscription` (crea el Resource Group)

**Dependencias:**
- Ninguna (es el punto de entrada)

**Responsabilidades:**
- Crear Resource Group
- Llamar módulos en orden de dependencias
- Gestionar outputs consolidados

**Inputs clave:**
- `environment`: "dev" | "test" | "prod"
- `location`: Región Azure (ej. "westeurope")
- `projectName`: Nombre del proyecto
- `sqlAdminPassword`: Contraseña del SQL Server (parámetro seguro)

**Outputs:**
- Resource Group ID
- App Service URI
- SQL Server FQDN
- Log Analytics Workspace ID
- Key Vault URI

---

### **modules/networking.bicep**
**Propósito:** Crear infraestructura de red segura y aislada.

**Componentes:**
- **VNet**: 10.0.0.0/16 con 2 subnets
  - App Service Subnet: 10.0.1.0/24 (con delegación a Microsoft.Web/serverFarms)
  - Private Endpoint Subnet: 10.0.2.0/24 (sin network policies)
- **NSG Rules**: Allow HTTP/HTTPS, Deny todos los demás
- **Service Endpoints**: SQL, KeyVault, Storage habilitados en App Service subnet

**Outputs:**
- `vnetId`
- `appServiceSubnetId`
- `privateEndpointSubnetId`
- `nsgId`

---

### **modules/sql-database.bicep**
**Propósito:** Desplegar Azure SQL Server + Database con autenticación AAD.

**Componentes:**
- **SQL Server**: AAD-only authentication (no SQL auth), TLS 1.2 minimum
- **Database**: Tier configurable (Basic, Standard, Premium)
- **Firewall Rules**: Allow Azure Services (necesario para Private Endpoints)
- **Transparent Data Encryption (TDE)**: Habilitado automáticamente
- **Diagnostic Settings**: SQLSecurityAuditEvents + SQLInsights → Log Analytics

**Seguridad:**
- Public network access: DISABLED (solo via Private Endpoint)
- Identidad: SystemAssigned
- Cifrado: TDE habilitado

**Parámetros:**
- `adminLogin`: Usuario administrador
- `adminPassword`: Contraseña (parámetro seguro)
- `databaseTier`: "Basic" | "Standard" | "Premium"

**Outputs:**
- `sqlServerId`
- `sqlServerName`
- `sqlServerFqdn`
- `sqlDatabaseId`
- `sqlDatabaseName`

---

### **modules/app-service.bicep**
**Propósito:** Desplegar App Service Plan + App Service con integración VNet.

**Componentes:**
- **App Service Plan**: SKU configurable (B1, B2, S1, etc.), Linux runtime
- **App Service**: .NET 8.0 LTS, HTTPS-only, TLS 1.2 minimum
- **Managed Identity**: SystemAssigned (para acceso a Key Vault y SQL)
- **VNet Integration**: Conexión a AppService Subnet con swift proxy
- **Auto-scaling**: Configurado para SKU B2 y superiores (CPU threshold 70%)
- **Diagnostic Settings**: HTTPLogs, ConsoleLogs, AppLogs, PlatformLogs

**App Settings:**
- Application Insights connection string
- Key Vault URI
- SQL Server connection details
- ASPNETCORE_ENVIRONMENT

**Outputs:**
- `appServiceId`
- `appServiceName`
- `appServiceUri`
- `managedIdentityPrincipalId` (para RBAC)
- `appServicePlanId`

---

### **modules/key-vault.bicep**
**Propósito:** Almacenamiento seguro de secretos con RBAC.

**Componentes:**
- **SKU**: Standard
- **Soft Delete**: Habilitado (90 días)
- **Purge Protection**: Habilitado
- **RBAC**: enableRbacAuthorization: true
- **Network**: defaultAction: Deny, bypass: AzureServices
- **Diagnostic Settings**: AuditEvent logs → Log Analytics

**Seguridad:**
- Public network access: DISABLED (solo via Private Endpoint)
- Sin acceso público

**Outputs:**
- `keyVaultId`
- `keyVaultName`
- `keyVaultUri`

---

### **modules/private-endpoint.bicep** (Genérico y Reutilizable)
**Propósito:** Crear Private Endpoints con DNS zones integradas para cualquier servicio.

**Características:**
- Genérico: Soporta múltiples tipos de servicio (SQL, Key Vault, Storage, etc.)
- DNS automático: Crea y vincula Private DNS Zones
- Multi-cloud: Usa `environment()` function para compatibilidad

**Parámetros:**
- `serviceName`: Nombre del servicio (sql, keyvault, blob, etc.)
- `privateLinkServiceId`: Resource ID del servicio PaaS
- `groupId`: Identificador del grupo (sqlServer, vault, blob, etc.)
- `subnetId`: Subnet donde crear el PE
- `vnetId`: VNet para vincular DNS Zone

**Mapeo de Servicios:**
- `sqlServer` → privatelink.database.windows.net (SQL Database)
- `vault` → privatelink.vaultcore.azure.net (Key Vault)
- `blob` → privatelink.blob.core.windows.net (Storage Blob)
- `file` → privatelink.file.core.windows.net (Storage File Share)
- `queue` → privatelink.queue.core.windows.net (Storage Queue)
- `table` → privatelink.table.core.windows.net (Storage Table)

**Outputs:**
- `privateEndpointId`
- `privateEndpointName`
- `privateDnsZoneId`
- `privateDnsZoneName`

---

### **modules/monitoring.bicep**
**Propósito:** Observabilidad centralizada con alertas.

**Componentes:**
- **Log Analytics Workspace**: PerGB2018 (pay-as-you-go), retención configurable
- **Application Insights**: Integrado con Log Analytics
- **Action Group**: Para notificaciones de alertas
- **Alert Rules**: 3 reglas predefinidas
  1. HTTP 5xx errors > 10/5min (severity 2)
  2. Response time p95 > 500ms (severity 3)
  3. Failed requests > 20% (severity 2)

**Alertas (deshabilitadas por defecto):**
- Activar según necesidad en Azure Portal o Bicep

**Outputs:**
- `logAnalyticsWorkspaceId`
- `logAnalyticsWorkspaceName`
- `appInsightsId`
- `appInsightsInstrumentationKey`
- `appInsightsConnectionString`
- `actionGroupId`

---

### **modules/rbac.bicep**
**Propósito:** Configurar permisos mínimos para Managed Identity.

**Role Assignments:**
1. **SQL DB Contributor** (App Service → SQL Server)
   - Role ID: `9b7fa17d-e63a-4f14-b0d0-5d2b24b8ee29`
   - Permite: Conectar a SQL con AAD

2. **Key Vault Secrets User** (App Service → Key Vault)
   - Role ID: `4633458b-17de-408a-b874-0dc8fde00a6d`
   - Permite: Leer secretos de Key Vault

**Principio:** Least privilege - solo permisos necesarios

**Outputs:**
- `sqlDbRoleAssignmentId`
- `keyVaultRoleAssignmentId`

---

## 🔧 Validación y Despliegue

### Prerequisitos

```bash
# Instalar Azure CLI
# https://learn.microsoft.com/en-us/cli/azure/install-azure-cli

# Instalar Bicep CLI (incluido con Azure CLI 2.20+)
az bicep install

# Iniciar sesión en Azure
az login
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### 1️⃣ Validación de Sintaxis

```bash
# Validar sintaxis Bicep
az bicep build --file bicep/main.bicep

# Output esperado: Archivo compilado ARM template en bicep/main.json
```

### 2️⃣ Linting (Verificar Best Practices)

```bash
# Verificar linting rules
az bicep lint --file bicep/main.bicep

# Output esperado: Sin errores ni warnings (0 issues)
```

### 3️⃣ Preview con What-If (Seguro - No Despliega)

```bash
# Vista previa de cambios (development)
az deployment sub create \
  --name kitten-missions-dev-what-if \
  --location westeurope \
  --template-file bicep/main.bicep \
  --parameters bicep/parameters/dev.parameters.json \
  --what-if

# Vista previa (production)
az deployment sub create \
  --name kitten-missions-prod-what-if \
  --location westeurope \
  --template-file bicep/main.bicep \
  --parameters bicep/parameters/prod.parameters.json \
  --what-if
```

**Output esperado:**
- Lista de recursos que serán creados/modificados/eliminados
- Cambios en configuración

### 4️⃣ Despliegue Real (Veremos en Actividad 6)

```bash
# Desplegar a development
az deployment sub create \
  --name kitten-missions-dev \
  --location westeurope \
  --template-file bicep/main.bicep \
  --parameters bicep/parameters/dev.parameters.json

# Desplegar a production
az deployment sub create \
  --name kitten-missions-prod \
  --location westeurope \
  --template-file bicep/main.bicep \
  --parameters bicep/parameters/prod.parameters.json
```

---

## 📝 Naming Conventions

### Patrón General
```
{resourceType}-{projectName}-{workloadName}-{environment}[-uniqueString]
```

### Ejemplos por Recurso

| Recurso | Patrón | Ejemplo |
|---------|--------|---------|
| Resource Group | `rg-{projectName}-{workloadName}-{environment}` | `rg-kitten-missions-api-dev` |
| VNet | `vnet-{projectName}-{workloadName}-{environment}` | `vnet-kitten-missions-api-dev` |
| Subnet (App) | `snet-appservice-{environment}` | `snet-appservice-dev` |
| Subnet (PE) | `snet-pe-{environment}` | `snet-pe-dev` |
| NSG | `nsg-{projectName}-{workloadName}-{environment}` | `nsg-kitten-missions-api-dev` |
| App Service Plan | `plan-{projectName}-{workloadName}-{environment}` | `plan-kitten-missions-api-dev` |
| App Service | `app-{projectName}-{workloadName}-{environment}` | `app-kitten-missions-api-dev` |
| SQL Server | `sqlsrv-{projectName}-{workloadName}-{environment}-{unique}` | `sqlsrv-kitten-missions-api-dev-a1b2c3` |
| SQL Database | `sqldb-{projectName}-{workloadName}` | `sqldb-kitten-missions-api` |
| Key Vault | `kv-{projectName}-{workloadName}-{environment}-{unique}` | `kv-kitten-missions-api-dev-x9y8z7` |
| Log Analytics | `log-{projectName}-{workloadName}-{environment}` | `log-kitten-missions-api-dev` |
| App Insights | `appi-{projectName}-{workloadName}-{environment}` | `appi-kitten-missions-api-dev` |
| Private Endpoint | `pe-{serviceName}-{projectName}-{workloadName}-{environment}` | `pe-sql-kitten-missions-api-dev` |

### Reglas Importantes

- ✅ Usar minúsculas (Azure requiere lowercase)
- ✅ Usar guiones (`-`) como separadores
- ✅ Nombres únicos con `uniqueString()` para SQL Server, Key Vault (DNS global)
- ❌ No usar underscores (`_`)
- ❌ No usar puntos (`.`) excepto en dominios

---

## 🌍 Variables de Entorno y Parámetros

### Archivo: `parameters/dev.parameters.json`

```json
{
  "environment": "dev",              // development
  "location": "westeurope",          // Región Azure
  "projectName": "kitten-missions",  // Nombre del proyecto
  "workloadName": "api",             // Tipo de carga de trabajo
  "tags": {
    "Environment": "Development",
    "Project": "Kitten Space Missions",
    "ManagedBy": "Bicep",
    "CostCenter": "Engineering"
  },
  "appServiceSku": "B1",             // B1, B2, S1, S2, P1, etc.
  "sqlDatabaseTier": "Basic",        // Basic, Standard, Premium
  "enableAutoShutdown": true,        // Auto-apagar de lunes a viernes 8pm
  "logAnalyticsRetentionDays": 7     // Retención de logs (dev = 7, prod = 30)
}
```

### Archivo: `parameters/prod.parameters.json`

```json
{
  "environment": "prod",
  "location": "westeurope",
  "projectName": "kitten-missions",
  "workloadName": "api",
  "tags": {
    "Environment": "Production",
    "Project": "Kitten Space Missions",
    "ManagedBy": "Bicep",
    "CostCenter": "Operations",
    "Criticality": "High"
  },
  "appServiceSku": "S1",             // SKU mayor para producción
  "sqlDatabaseTier": "Standard",     // Tier mayor para producción
  "enableAutoShutdown": false,       // Siempre activo
  "logAnalyticsRetentionDays": 30    // Retención extendida
}
```

### Variables de Entorno del Sistema

```bash
# Definir antes del despliegue (opcional)
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_LOCATION="westeurope"
export PROJECT_NAME="kitten-missions"
export ENVIRONMENT="dev"
```

---

## 🔐 Seguridad - Consideraciones Importantes

### Parámetros Seguros

```bicep
@description('SQL Server admin password')
@secure()
param sqlAdminPassword string  // NO hardcodear contraseña
```

**Cómo proporcionar:**
1. Vía parámetro: `--parameters @params.json`
2. Vía CLI: `--parameters sqlAdminPassword="SecurePassword123!"`
3. Vía Key Vault reference (recomendado en `parameters/dev.parameters.json`):

```json
"sqlAdminPassword": {
  "reference": {
    "keyVault": {
      "id": "/subscriptions/{subscriptionId}/resourceGroups/rg-secrets/providers/Microsoft.KeyVault/vaults/kv-secrets"
    },
    "secretName": "sql-admin-password"
  }
}
```

### Managed Identity (No Hardcoded Secrets)

```bicep
identity: {
  type: 'SystemAssigned'
}
```

- App Service obtiene identidad del sistema
- Acceso a SQL y Key Vault vía RBAC
- **Ventaja**: Sin credenciales hardcodeadas en el código

### Private Endpoints (Network Isolation)

```bicep
// SQL, Key Vault, Storage - accesibles SOLO vía Private Endpoints
publicNetworkAccess: 'Disabled'
```

- Tráfico no sale de la VNet
- DNS privado resuelve a IPs privadas
- Seguridad Zero Trust

### RBAC (Least Privilege)

```bicep
// Solo permisos necesarios
- SQL DB Contributor (no Owner o Contributor general)
- Key Vault Secrets User (no admin)
```

---

## 🐛 Troubleshooting Común

### Error: "Secure parameter default not allowed"

**Mensaje:**
```
Error BCP037: The property "transparentDataEncryption" is not allowed...
```

**Causa:** Parámetro `@secure()` con valor por defecto hardcodeado.

**Solución:**
```bicep
// ❌ MAL
@secure()
param sqlAdminPassword string = 'password123'

// ✅ BIEN
@secure()
param sqlAdminPassword string  // Sin default
```

---

### Error: "Private Endpoint DNS Zone not linking"

**Mensaje:**
```
Error: Private DNS Zone Group creation failed
```

**Causa:** Private Endpoint subnet requiere `privateEndpointNetworkPolicies: Disabled`

**Solución:** Verificar en `networking.bicep`:
```bicep
delegations: [
  {
    name: 'delegation'
    properties: {
      serviceName: 'Microsoft.Web/serverFarms'
    }
  }
]
privateEndpointNetworkPolicies: 'Disabled'
```

---

### Error: "SQL Server public access must be disabled"

**Mensaje:**
```
Error: Cannot connect to SQL Server from public internet
```

**Causa:** `publicNetworkAccess: 'Enabled'` sin Private Endpoint.

**Solución:** En `sql-database.bicep`:
```bicep
publicNetworkAccess: 'Disabled'  // ✅ Solo Private Endpoints
```

---

### Error: "Key Vault RBAC role not assigned"

**Mensaje:**
```
Error: Managed identity does not have permission to access Key Vault
```

**Causa:** Role assignment falta o tiene principalId incorrecto.

**Solución:** Verificar en `rbac.bicep`:
```bicep
// Verificar que principalId es el ObjectId correcto del App Service
principalId: appServicePrincipalId
principalType: 'ServicePrincipal'
```

**Debug:**
```bash
# Obtener ObjectId del App Service
az webapp identity show --resource-group rg-kitten-missions-api-dev \
  --name app-kitten-missions-api-dev --query principalId
```

---

### Error: "Log Analytics workspace retention not updating"

**Mensaje:**
```
Warning: retentionInDays not changed to 7
```

**Causa:** Log Analytics cache o ARM template cached.

**Solución:**
```bash
# Forzar redeployment
az deployment group delete --resource-group rg-kitten-missions-api-dev \
  --name monitoring-deployment

# Redeploy
az deployment sub create ...
```

---

### Warning: "Hardcoded environment URLs"

**Mensaje:**
```
Warning no-hardcoded-env-urls: Found hardcoded host "database.windows.net"
```

**Causa:** URLs hardcodeadas en lugar de usar `environment()` function.

**Solución:** Usar suffixes dinámicos:
```bicep
// ✅ BIEN
var dnsZoneName = 'privatelink${environment().suffixes.sqlServerHostname}'

// ❌ MAL
var dnsZoneName = 'privatelink.database.windows.net'
```

---

### Performance: "App Service slow startup"

**Causa:** App Service Plan B1 muy pequeño, o no tiene "Always On".

**Solución:**
```bicep
// En app-service.bicep
alwaysOn: true  // ✅ Mantener caliente
siteConfig: {
  linuxFxVersion: 'DOTNETCORE|8.0'
}
```

Para dev puedes usar B1, para prod usa S1 o superior.

---

## 📚 Referencias y Recursos

- [Azure Bicep Documentation](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure Best Practices](https://learn.microsoft.com/en-us/azure/cloud-adoption-framework/ready/enterprise-scale/)
- [Bicep Linter Rules](https://learn.microsoft.com/en-us/azure/azure-resource-manager/bicep/linter-rule-no-hardcoded-env-urls)
- [Private Endpoints Guide](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Managed Identity in App Service](https://learn.microsoft.com/en-us/azure/app-service/overview-managed-identity)

---

## ✅ Checklist Pre-Deployment

- [ ] Variables de entorno configuradas (`AZURE_SUBSCRIPTION_ID`, etc.)
- [ ] Archivo de parámetros actualizado (`parameters/dev.parameters.json`)
- [ ] SQL Admin password guardado en Key Vault o variables seguras
- [ ] Bicep validation OK: `az bicep lint --file bicep/main.bicep`
- [ ] What-if preview revisado: cambios esperados confirmados
- [ ] Tagging strategy alineado con gobernanza del proyecto
- [ ] Cost estimation revisado (presupuesto aprobado)
- [ ] Backup/restore procedures documentados
- [ ] Monitoring alerts configuradas
- [ ] Acceso RBAC verificado para el equipo

---

## 📞 Soporte y Preguntas

Para preguntas o issues:
1. Revisar sección **Troubleshooting** arriba
2. Verificar logs de despliegue: `az deployment sub list --query "[].{Name:name, ProvisioningState:properties.provisioningState}"`
3. Abrir issue en GitHub con detalles del error

---

**Última actualización:** Enero 2026  
**Versión Bicep:** 2021-09-01+  
**Azure CLI:** 2.20+
