#!/bin/bash
# Script de diagnóstico para problemas AVIF/HEIF no libvips

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Diagnóstico AVIF/HEIF - libvips              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

# Função para verificar comando
check_command() {
    if command -v $1 &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 encontrado"
        return 0
    else
        echo -e "${RED}✗${NC} $1 não encontrado"
        return 1
    fi
}

# Função para verificar pacote
check_package() {
    if pkg-config --exists $1 2>/dev/null; then
        VERSION=$(pkg-config --modversion $1)
        echo -e "${GREEN}✓${NC} $1 instalado: v$VERSION"
        return 0
    else
        echo -e "${RED}✗${NC} $1 não instalado"
        return 1
    fi
}

echo -e "${YELLOW}1. Verificando comandos básicos...${NC}"
check_command vips
check_command pkg-config
echo ""

echo -e "${YELLOW}2. Verificando libvips...${NC}"
if check_command vips; then
    VIPS_VERSION=$(vips --version 2>/dev/null | head -n1)
    echo -e "   Versão: ${GREEN}$VIPS_VERSION${NC}"
    
    echo ""
    echo -e "   ${BLUE}Módulos instalados:${NC}"
    vips --vips-version 2>/dev/null | grep -A50 "^modules:" | head -n20
    
    echo ""
    echo -e "   ${BLUE}Verificando suporte HEIF:${NC}"
    if vips --vips-version 2>/dev/null | grep -q "heif"; then
        echo -e "   ${GREEN}✓${NC} Suporte HEIF detectado"
        HEIF_SUPPORT=1
    else
        echo -e "   ${RED}✗${NC} Suporte HEIF NÃO detectado"
        HEIF_SUPPORT=0
    fi
fi
echo ""

echo -e "${YELLOW}3. Verificando bibliotecas HEIF...${NC}"
check_package libheif || LIBHEIF_MISSING=1
check_package libde265 || true
check_package x265 || true
check_package aom || true
echo ""

echo -e "${YELLOW}4. Verificando codecs de vídeo (para AV1)...${NC}"
if ldconfig -p 2>/dev/null | grep -q "libaom"; then
    echo -e "${GREEN}✓${NC} libaom (AV1) encontrado"
else
    echo -e "${RED}✗${NC} libaom (AV1) não encontrado"
fi

if ldconfig -p 2>/dev/null | grep -q "libx265"; then
    echo -e "${GREEN}✓${NC} libx265 (HEVC) encontrado"
else
    echo -e "${RED}✗${NC} libx265 (HEVC) não encontrado"
fi
echo ""

echo -e "${YELLOW}5. Testando encoding AVIF via CLI...${NC}"
if [ $HEIF_SUPPORT -eq 1 ]; then
    # Criar imagem de teste
    echo -e "   Criando imagem de teste..."
    if vips black test_diag.v 100 100 2>/dev/null; then
        echo -e "   ${GREEN}✓${NC} Imagem criada"
        
        # Tentar salvar como AVIF com AV1
        echo -e "   Tentando salvar como AVIF (AV1)..."
        if vips heifsave test_diag.v test_diag_av1.avif[Q=75,compression=av1] 2>&1; then
            echo -e "   ${GREEN}✓${NC} AVIF (AV1) funcionou!"
            SIZE=$(stat -f%z test_diag_av1.avif 2>/dev/null || stat -c%s test_diag_av1.avif 2>/dev/null)
            echo -e "   Tamanho: ${GREEN}$SIZE bytes${NC}"
            rm -f test_diag_av1.avif
        else
            echo -e "   ${RED}✗${NC} AVIF (AV1) falhou"
        fi
        
        # Tentar salvar como AVIF com HEVC
        echo -e "   Tentando salvar como AVIF (HEVC)..."
        if vips heifsave test_diag.v test_diag_hevc.avif[Q=75,compression=hevc] 2>&1; then
            echo -e "   ${GREEN}✓${NC} AVIF (HEVC) funcionou!"
            SIZE=$(stat -f%z test_diag_hevc.avif 2>/dev/null || stat -c%s test_diag_hevc.avif 2>/dev/null)
            echo -e "   Tamanho: ${GREEN}$SIZE bytes${NC}"
            rm -f test_diag_hevc.avif
        else
            echo -e "   ${RED}✗${NC} AVIF (HEVC) falhou"
        fi
        
        rm -f test_diag.v
    fi
else
    echo -e "   ${YELLOW}Pulando (sem suporte HEIF)${NC}"
fi
echo ""

echo -e "${YELLOW}6. Verificando bindings Rust...${NC}"
if [ -f "Cargo.toml" ]; then
    LIBVIPS_VERSION=$(grep "^libvips" Cargo.toml | head -n1)
    echo -e "   ${BLUE}Cargo.toml:${NC} $LIBVIPS_VERSION"
else
    echo -e "   ${YELLOW}Cargo.toml não encontrado${NC}"
fi
echo ""

# Diagnóstico e recomendações
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  DIAGNÓSTICO                                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

ISSUES=0

if [ $HEIF_SUPPORT -eq 0 ]; then
    echo -e "${RED}[CRÍTICO]${NC} libvips sem suporte HEIF"
    echo -e "  ${YELLOW}Solução:${NC}"
    echo -e "    1. Instalar libheif:"
    echo -e "       ${BLUE}sudo apt-get install libheif-dev libaom-dev libde265-dev libx265-dev${NC}"
    echo -e "    2. Recompilar libvips do source:"
    echo -e "       ${BLUE}cd /tmp${NC}"
    echo -e "       ${BLUE}wget https://github.com/libvips/libvips/releases/download/v8.15.0/vips-8.15.0.tar.xz${NC}"
    echo -e "       ${BLUE}tar xf vips-8.15.0.tar.xz && cd vips-8.15.0${NC}"
    echo -e "       ${BLUE}./configure && make && sudo make install && sudo ldconfig${NC}"
    echo ""
    ISSUES=1
fi

if [ ! -z "$LIBHEIF_MISSING" ]; then
    echo -e "${YELLOW}[AVISO]${NC} libheif não detectado via pkg-config"
    echo -e "  ${YELLOW}Solução:${NC}"
    echo -e "    ${BLUE}sudo apt-get install libheif-dev${NC}"
    echo ""
    ISSUES=1
fi

if ! ldconfig -p 2>/dev/null | grep -q "libaom"; then
    echo -e "${YELLOW}[AVISO]${NC} libaom (AV1) não encontrado"
    echo -e "  Encoding AVIF com AV1 não funcionará"
    echo -e "  ${YELLOW}Solução:${NC}"
    echo -e "    ${BLUE}sudo apt-get install libaom-dev${NC}"
    echo ""
    ISSUES=1
fi

if [ $ISSUES -eq 0 ]; then
    echo -e "${GREEN}✓ Tudo parece estar OK!${NC}"
    echo ""
    echo -e "${BLUE}Próximos passos:${NC}"
    echo -e "  1. Execute seu código Rust com debug:"
    echo -e "     ${BLUE}VIPS_WARNING=1 G_MESSAGES_DEBUG=VIPS cargo run${NC}"
    echo ""
    echo -e "  2. Adicione captura de erro detalhado:"
    echo -e "     ${BLUE}let vips_error = libvips::error_buffer();${NC}"
    echo -e "     ${BLUE}eprintln!(\"VIPS Error: {}\", vips_error);${NC}"
    echo ""
    echo -e "  3. Verifique se a imagem está em formato compatível:"
    echo -e "     - sRGB colorspace"
    echo -e "     - 8-bit depth"
    echo -e "     - RGB ou RGBA"
fi

echo ""
echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  CÓDIGO RUST RECOMENDADO                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
echo ""

cat << 'EOF'
use libvips::{ops, VipsImage};

pub fn encode_avif_safe(img: &VipsImage, quality: i32) -> Result<Vec<u8>, String> {
    // Ativar debug
    std::env::set_var("VIPS_WARNING", "1");
    libvips::error_buffer_clear();
    
    // Converter para formato compatível
    let mut processed = img.clone();
    
    // Garantir sRGB
    if processed.image_get_interpretation() != libvips::VipsInterpretation::Srgb {
        processed = ops::colourspace(&processed, libvips::VipsInterpretation::Srgb)
            .map_err(|e| format!("Colorspace error: {} - {}", e, libvips::error_buffer()))?;
    }
    
    // Garantir 8-bit
    if processed.image_get_format() != libvips::enums::BandFormat::Uchar {
        processed = ops::cast(&processed, libvips::enums::BandFormat::Uchar)
            .map_err(|e| format!("Cast error: {} - {}", e, libvips::error_buffer()))?;
    }
    
    // Tentar AVIF
    let options = ops::HeifsaveBufferOptions {
        q: quality,
        bitdepth: 8,
        lossless: false,
        compression: ops::ForeignHeifCompression::Av1,
        effort: 4,
        subsample_mode: ops::ForeignSubsample::Off,
        strip: true,
        ..Default::default()
    };
    
    ops::heifsave_buffer_with_opts(&processed, &options)
        .map_err(|e| {
            let vips_err = libvips::error_buffer();
            format!("AVIF encoding failed: {}\nVIPS details: {}", e, vips_err)
        })
}
EOF

echo ""
echo -e "${GREEN}Diagnóstico concluído!${NC}"
echo ""
echo -e "Salve a saída completa se precisar de ajuda:"
echo -e "  ${BLUE}./diagnose-avif.sh > diagnostic.log 2>&1${NC}"