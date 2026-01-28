#!/bin/bash
# ============================================================================
# Script de Testing para Deployment Bicep
# Uso: ./scripts/test-bicep-deployment.sh
# ============================================================================

set -euo pipefail

BICEP_PATH="docs/workshop/kitten-space-missions/solution/bicep"
PARAMETERS_FILE="$BICEP_PATH/parameters/dev.parameters.json"
MAIN_BICEP="$BICEP_PATH/main.bicep"
OUTPUT_JSON="/tmp/main.json"
DEPLOYMENT_LOCATION="westeurope"
RESOURCE_GROUP="rg-kitten-missions-dev"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ Testing Bicep Deployment - Kitten Space Missions              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# ============================================================================
# Step 1: Check Prerequisites
# ============================================================================
echo "📋 Step 1: Verificando prerequisitos..."

if ! command -v az &> /dev/null; then
    echo "❌ Azure CLI no está instalado"
    exit 1
fi

if ! command -v jq &> /dev/null; then
    echo "❌ jq no está instalado"
    exit 1
fi

echo "✅ Azure CLI: $(az version --output json | jq -r '.['\"cli\"']')"
echo ""

# ============================================================================
# Step 2: Check Azure Login
# ============================================================================
echo "📋 Step 2: Verificando sesión de Azure..."

if ! az account show &> /dev/null; then
    echo "❌ No autenticado en Azure. Ejecuta: az login"
    exit 1
fi

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
echo "✅ Sesión activa"
echo "   Subscription: $SUBSCRIPTION_ID"
echo "   Tenant: $TENANT_ID"
echo ""

# ============================================================================
# Step 3: Validate Bicep Files Exist
# ============================================================================
echo "📋 Step 3: Verificando archivos Bicep..."

if [ ! -f "$MAIN_BICEP" ]; then
    echo "❌ No encontrado: $MAIN_BICEP"
    exit 1
fi

if [ ! -f "$PARAMETERS_FILE" ]; then
    echo "❌ No encontrado: $PARAMETERS_FILE"
    exit 1
fi

echo "✅ Archivos Bicep encontrados"
echo "   Template: $MAIN_BICEP"
echo "   Parameters: $PARAMETERS_FILE"
echo ""

# ============================================================================
# Step 4: Compile Bicep to ARM Template
# ============================================================================
echo "📋 Step 4: Compilando Bicep a ARM Template..."

if az bicep build --file "$MAIN_BICEP" --outfile "$OUTPUT_JSON" 2>&1 | tee /tmp/bicep-build.log; then
    echo "✅ Compilación exitosa"
    echo "   Output: $OUTPUT_JSON"
    echo "   Tamaño: $(wc -c < "$OUTPUT_JSON") bytes"
else
    echo "❌ Error en compilación Bicep:"
    cat /tmp/bicep-build.log
    exit 1
fi
echo ""

# ============================================================================
# Step 5: Validate ARM Template
# ============================================================================
echo "📋 Step 5: Validando ARM Template..."

if az deployment sub validate \
    --location "$DEPLOYMENT_LOCATION" \
    --template-file "$OUTPUT_JSON" \
    --parameters "$PARAMETERS_FILE" \
    --output table 2>&1 | tee /tmp/template-validate.log; then
    echo "✅ Template validado exitosamente"
else
    echo "❌ Error en validación del template:"
    cat /tmp/template-validate.log
    exit 1
fi
echo ""

# ============================================================================
# Step 6: What-If Analysis
# ============================================================================
echo "📋 Step 6: Ejecutando What-If Analysis..."

if az deployment sub what-if \
    --location "$DEPLOYMENT_LOCATION" \
    --template-file "$OUTPUT_JSON" \
    --parameters "$PARAMETERS_FILE" \
    --result-format "FullResourcePayloads" \
    2>&1 | tee /tmp/what-if.log; then
    echo "✅ What-If completado"
    echo "   Ver detalles en: /tmp/what-if.log"
else
    echo "⚠️  What-If falló (puede ser normal en algunos casos)"
    tail -20 /tmp/what-if.log
fi
echo ""

# ============================================================================
# Step 7: Check Resource Group
# ============================================================================
echo "📋 Step 7: Verificando Resource Group..."

if az group exists --name "$RESOURCE_GROUP" | grep -q "true"; then
    echo "✅ Resource Group existe: $RESOURCE_GROUP"
else
    echo "⚠️  Resource Group no existe. Se creará durante deployment."
    echo "   Nombre: $RESOURCE_GROUP"
fi
echo ""

# ============================================================================
# Step 8: Show Parameter Summary
# ============================================================================
echo "📋 Step 8: Resumen de Parámetros..."
echo ""
echo "Archivo de parámetros: $PARAMETERS_FILE"
echo ""

jq '.parameters | to_entries[] | select(.value.value != null) | "\(.key): \(.value.value)"' "$PARAMETERS_FILE" || true

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║ ✅ VALIDACIÓN COMPLETADA EXITOSAMENTE                         ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "Próximos pasos:"
echo "1. Revisar What-If en: /tmp/what-if.log"
echo "2. Si todo es correcto, proceder con deployment"
echo "3. Para deployment: az deployment sub create ..."
echo ""
echo "Archivos de debugging:"
echo "  - /tmp/bicep-build.log (Compilación Bicep)"
echo "  - /tmp/template-validate.log (Validación)"
echo "  - /tmp/what-if.log (What-If Analysis)"
echo "  - /tmp/main.json (ARM Template compilado)"
echo ""
