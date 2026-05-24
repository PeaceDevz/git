#!/data/data/com.termux/files/usr/bin/bash

#############################################################
# GitHub Pages FULL AUTO DEPLOY - FINAL FIX
#############################################################

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

clear
echo "======================================"
echo " GitHub Pages Auto Deploy"
echo "======================================"

##############################
# FIX GIT SAFE DIRECTORY
##############################
git config --global --add safe.directory "$PWD" 2>/dev/null
git config --global safe.directory "*" 2>/dev/null

##############################
# INSTALL DEPENDENCIES
##############################
command -v git >/dev/null 2>&1 || pkg install git -y
command -v node >/dev/null 2>&1 || pkg install nodejs -y
command -v npm >/dev/null 2>&1 || pkg install nodejs -y

##############################
# GITHUB AUTH
##############################
GH_AVAILABLE=false
command -v gh >/dev/null 2>&1 && GH_AVAILABLE=true

if [ "$GH_AVAILABLE" = true ]; then
    gh auth status >/dev/null 2>&1 || gh auth login --web
    USERNAME=$(gh api user -q .login 2>/dev/null)
else
    read -p "GitHub username: " USERNAME
fi

[ -z "$USERNAME" ] && error "No username" && exit 1
success "User: $USERNAME"

git config --global user.name "$USERNAME"
git config --global user.email "$USERNAME@users.noreply.github.com"

##############################
# PROJECT SETUP
##############################
PROJECT_NAME=$(basename "$PWD")
log "Project: $PROJECT_NAME"

# Detect build dir
BUILD_DIR="."
if [ -f "package.json" ]; then
    if grep -qi "vite" package.json; then
        BUILD_DIR="dist"
    elif grep -qi "react" package.json; then
        BUILD_DIR="build"
    fi
fi

##############################
# BUILD IF NEEDED
##############################
if [ -f "package.json" ] && grep -q '"build"' package.json; then
    log "Installing dependencies..."
    npm install --no-audit --no-fund
    
    log "Building..."
    npm run build
    
    if [ ! -d "$BUILD_DIR" ]; then
        error "Build failed - $BUILD_DIR not found"
        exit 1
    fi
fi

# Ensure build dir has index.html
if [ "$BUILD_DIR" = "." ] && [ ! -f "index.html" ]; then
    error "index.html not found"
    exit 1
fi

touch "$BUILD_DIR/.nojekyll"
success "Build ready: $BUILD_DIR"

##############################
# GIT OPERATIONS
##############################
[ ! -d ".git" ] && git init

# Create/switch to main branch
git checkout -B main 2>/dev/null

# Stage and commit
git add . 2>/dev/null
if [ -n "$(git status --porcelain)" ]; then
    git commit -m "Deploy: $(date '+%Y-%m-%d %H:%M:%S')"
    success "Committed"
else
    warn "No changes"
fi

# Setup remote
if ! git remote get-url origin >/dev/null 2>&1; then
    if [ "$GH_AVAILABLE" = true ]; then
        gh repo create "$PROJECT_NAME" --public --source=. --remote=origin --push 2>/dev/null
    else
        git remote add origin "https://github.com/$USERNAME/$PROJECT_NAME.git"
    fi
fi

# Push
log "Pushing to GitHub..."
git push -u origin main 2>/dev/null || git push -u origin main --force

success "Source pushed"

##############################
# DEPLOY TO GH-PAGES (FIXED)
##############################
log "Deploying to GitHub Pages..."

# Install locally if not present
if [ -f "package.json" ]; then
    if ! grep -q "gh-pages" package.json; then
        log "Adding gh-pages package..."
        npm install --save-dev gh-pages --no-audit --no-fund
    fi
else
    # No package.json - install globally
    npm install -g gh-pages --no-audit --no-fund 2>/dev/null
fi

# Deploy using the correct method
if [ -f "node_modules/.bin/gh-pages" ]; then
    # Local install
    log "Using local gh-pages..."
    node node_modules/gh-pages/bin/gh-pages.js \
        -d "$BUILD_DIR" \
        -b gh-pages \
        --dotfiles \
        --no-history \
        --no-user
elif [ -f "node_modules/gh-pages/bin/gh-pages.js" ]; then
    # Direct node execution
    log "Running gh-pages directly..."
    node node_modules/gh-pages/bin/gh-pages.js \
        -d "$BUILD_DIR" \
        -b gh-pages \
        --dotfiles \
        --no-history
elif command -v gh-pages >/dev/null 2>&1; then
    # Global install
    log "Using global gh-pages..."
    gh-pages -d "$BUILD_DIR" -b gh-pages --dotfiles --no-history
else
    # Force local install and retry
    log "Installing gh-pages locally..."
    npm install gh-pages --no-save --no-audit --no-fund
    npx gh-pages -d "$BUILD_DIR" -b gh-pages --dotfiles --no-history
fi

if [ $? -eq 0 ]; then
    success "Deployed to gh-pages branch"
else
    error "Deployment failed"
    exit 1
fi

##############################
# ENABLE PAGES
##############################
if [ "$GH_AVAILABLE" = true ]; then
    sleep 2
    gh api -X POST "repos/$USERNAME/$PROJECT_NAME/pages" \
        -f source[branch]="gh-pages" \
        -f source[path]="/" 2>/dev/null
fi

##############################
# DONE
##############################
FINAL_URL="https://$USERNAME.github.io/$PROJECT_NAME"

echo ""
echo "======================================"
echo "✅ DEPLOYMENT SUCCESSFUL"
echo "======================================"
echo ""
echo "🌐 $FINAL_URL"
echo ""
echo "⏱️  Live in 1-5 minutes"
echo "📁 https://github.com/$USERNAME/$PROJECT_NAME"
echo ""