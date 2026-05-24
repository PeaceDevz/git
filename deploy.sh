#!/data/data/com.termux/files/usr/bin/bash

#############################################################
# GitHub Pages FULL AUTO DEPLOY - TERMUX FIXED
# Android Termux Compatible
#############################################################

##############################
# CONFIG
##############################

DEFAULT_BRANCH="main"

##############################
# COLORS
##############################

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

##############################
# LOGGING
##############################

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

##############################
# HEADER
##############################

clear

echo "======================================"
echo " GitHub Pages Auto Deploy"
echo " Android Termux"
echo "======================================"

##############################
# FIX: GIT SAFE DIRECTORY
##############################

# Get current directory and add to git safe directories
CURRENT_DIR="$PWD"
log "Setting up git safe directory: $CURRENT_DIR"

# Fix the dubious ownership error
git config --global --add safe.directory "$CURRENT_DIR" 2>/dev/null

# Also add common Termux storage paths
git config --global --add safe.directory "/storage/emulated/0/acode/testapp" 2>/dev/null
git config --global --add safe.directory "/storage/emulated/0" 2>/dev/null
git config --global --add safe.directory "/data/data/com.termux/files/home" 2>/dev/null

success "Git safe directory configured"

##############################
# AUTO INSTALL
##############################

install_if_missing() {
    command -v "$1" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        warn "$1 not installed"
        pkg install "$2" -y
        if [ $? -ne 0 ]; then
            error "Failed installing $1"
            exit 1
        fi
        success "$1 installed successfully"
    fi
}

# Install required packages
install_if_missing git git
install_if_missing nodejs nodejs
install_if_missing npm nodejs

# Check for gh (GitHub CLI) - optional but recommended
command -v gh >/dev/null 2>&1
if [ $? -ne 0 ]; then
    warn "GitHub CLI not installed - will use git remote"
    GH_AVAILABLE=false
else
    GH_AVAILABLE=true
fi

##############################
# STORAGE ACCESS
##############################

termux-setup-storage >/dev/null 2>&1

##############################
# GITHUB LOGIN (if gh available)
##############################

if [ "$GH_AVAILABLE" = true ]; then
    log "Checking GitHub authentication..."
    
    gh auth status >/dev/null 2>&1
    
    if [ $? -ne 0 ]; then
        warn "GitHub login required"
        gh auth login --web --git-protocol https
        if [ $? -ne 0 ]; then
            error "GitHub login failed"
            exit 1
        fi
    fi
    
    success "GitHub authenticated"
    
    USERNAME=$(gh api user -q .login 2>/dev/null)
    if [ -z "$USERNAME" ]; then
        USERNAME=$(gh repo view --json owner -q .owner.login 2>/dev/null)
    fi
else
    echo ""
    read -p "Enter GitHub username: " USERNAME
    if [ -z "$USERNAME" ]; then
        error "GitHub username required"
        exit 1
    fi
fi

if [ -z "$USERNAME" ]; then
    error "Cannot get GitHub username"
    exit 1
fi

success "GitHub user: $USERNAME"

##############################
# AUTO GIT CONFIG
##############################

git config --global user.name "$USERNAME"
git config --global user.email "$USERNAME@users.noreply.github.com"

# Fix for Termux - disable git security warnings
git config --global safe.directory "*" 2>/dev/null

##############################
# PROJECT INFO
##############################

PROJECT_NAME=$(basename "$PWD")

if [ -z "$PROJECT_NAME" ]; then
    error "Cannot detect project name"
    exit 1
fi

log "Project name: $PROJECT_NAME"

##############################
# DETECT PROJECT TYPE
##############################

PROJECT_TYPE="static"
BUILD_DIR="."

if [ -f "package.json" ]; then
    if grep -qi "vite" package.json; then
        PROJECT_TYPE="vite"
        BUILD_DIR="dist"
    elif grep -qi "react" package.json; then
        PROJECT_TYPE="react"
        BUILD_DIR="build"
    elif grep -qi "angular" package.json; then
        PROJECT_TYPE="angular"
        BUILD_DIR="dist/$PROJECT_NAME"
    else
        PROJECT_TYPE="node"
        BUILD_DIR="dist"
    fi
fi

success "Project type: $PROJECT_TYPE"
log "Build directory: $BUILD_DIR"

##############################
# STATIC VALIDATION
##############################

if [ "$PROJECT_TYPE" = "static" ]; then
    if [ ! -f "index.html" ] && [ ! -f "index.htm" ]; then
        error "No index.html found in static project"
        exit 1
    fi
fi

##############################
# INSTALL DEPENDENCIES (local)
##############################

if [ "$PROJECT_TYPE" != "static" ]; then
    log "Installing dependencies..."
    
    if [ ! -f "package.json" ]; then
        error "package.json not found"
        exit 1
    fi
    
    npm install --no-audit --no-fund 2>/dev/null
    if [ $? -ne 0 ]; then
        error "npm install failed"
        exit 1
    fi
    
    # Install gh-pages locally if needed
    if ! grep -q "gh-pages" package.json; then
        log "Adding gh-pages as dev dependency..."
        npm install --save-dev gh-pages 2>/dev/null
    fi
fi

##############################
# BUILD
##############################

if [ "$PROJECT_TYPE" != "static" ]; then
    log "Building project..."
    
    if ! grep -q '"build"' package.json; then
        error "No build script in package.json"
        exit 1
    fi
    
    npm run build 2>/dev/null
    if [ $? -ne 0 ]; then
        error "Build failed"
        exit 1
    fi
fi

##############################
# VALIDATE BUILD
##############################

if [ ! -d "$BUILD_DIR" ]; then
    error "Build folder missing: $BUILD_DIR"
    exit 1
fi

# Check if build directory is empty
if [ -z "$(ls -A $BUILD_DIR 2>/dev/null)" ]; then
    error "Build directory is empty"
    exit 1
fi

success "Build folder ready"

##############################
# NOJEKYLL
##############################

touch "$BUILD_DIR/.nojekyll"

##############################
# GIT INIT
##############################

if [ ! -d ".git" ]; then
    log "Initializing git..."
    git init
    if [ $? -ne 0 ]; then
        error "git init failed"
        exit 1
    fi
fi

##############################
# ENSURE MAIN BRANCH
##############################

# Fix: Check if branch exists first
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)
if [ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]; then
    git checkout -B "$DEFAULT_BRANCH" 2>/dev/null
fi

##############################
# GITIGNORE
##############################

if [ ! -f ".gitignore" ]; then
    cat > .gitignore <<EOF
node_modules/
dist/
build/
.cache/
.vite/
.DS_Store
*.log
.env
.env.local
EOF
fi

##############################
# FIX: STAGE FILES (better approach)
##############################

log "Staging files..."

# Add all files except those in gitignore
git add . 2>/dev/null

# Also add force any new files that might be ignored
git add -f index.html 2>/dev/null
git add -f "$BUILD_DIR" 2>/dev/null

##############################
# FIX: COMMIT (use git status instead of diff --cached)
##############################

# Check if there are changes to commit
if [ -z "$(git status --porcelain)" ]; then
    warn "No new changes to commit"
else
    log "Creating commit..."
    git commit -m "Auto deploy: $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null
    if [ $? -ne 0 ]; then
        error "Git commit failed"
        # Show actual error
        git commit -m "Auto deploy: $(date '+%Y-%m-%d %H:%M:%S')"
        exit 1
    fi
    success "Changes committed"
fi

##############################
# CREATE REMOTE
##############################

git remote get-url origin >/dev/null 2>&1
if [ $? -ne 0 ]; then
    log "Creating GitHub repository..."
    
    if [ "$GH_AVAILABLE" = true ]; then
        gh repo create "$PROJECT_NAME" \
            --public \
            --source=. \
            --remote=origin \
            --push 2>/dev/null
        
        if [ $? -ne 0 ]; then
            REMOTE_URL="https://github.com/$USERNAME/$PROJECT_NAME.git"
            git remote add origin "$REMOTE_URL" 2>/dev/null
        else
            success "Repository created via GitHub CLI"
        fi
    else
        REMOTE_URL="https://github.com/$USERNAME/$PROJECT_NAME.git"
        log "Please create repository at: https://github.com/new"
        read -p "Press Enter after creating the repository..."
        git remote add origin "$REMOTE_URL" 2>/dev/null
    fi
else
    warn "Remote already exists"
fi

##############################
# PUSH SOURCE
##############################

log "Uploading source code..."

# Try to push, handle errors gracefully
git push -u origin "$DEFAULT_BRANCH" 2>/dev/null

if [ $? -ne 0 ]; then
    warn "Push failed, attempting to pull and merge..."
    
    git pull origin "$DEFAULT_BRANCH" --allow-unrelated-histories --no-rebase 2>/dev/null
    
    if [ $? -ne 0 ]; then
        warn "Pull failed, forcing push..."
        git push -u origin "$DEFAULT_BRANCH" --force 2>/dev/null
    else
        git push -u origin "$DEFAULT_BRANCH" 2>/dev/null
    fi
    
    if [ $? -ne 0 ]; then
        error "Git push failed after retry"
        exit 1
    fi
fi

success "Source uploaded"

##############################
# DEPLOY GITHUB PAGES
##############################

log "Deploying to GitHub Pages..."

# Check if BUILD_DIR exists before deployment
if [ ! -d "$BUILD_DIR" ]; then
    error "Build directory $BUILD_DIR not found"
    exit 1
fi

# Deploy using npx (local installation)
if [ -f "node_modules/.bin/gh-pages" ]; then
    npx gh-pages \
        -d "$BUILD_DIR" \
        -b gh-pages \
        --dotfiles \
        --no-history 2>/dev/null
    
    DEPLOY_STATUS=$?
elif [ -f "node_modules/gh-pages/bin/gh-pages.js" ]; then
    node node_modules/gh-pages/bin/gh-pages.js \
        -d "$BUILD_DIR" \
        -b gh-pages \
        --dotfiles 2>/dev/null
    
    DEPLOY_STATUS=$?
else
    # Try global install
    npm install -g gh-pages --no-audit 2>/dev/null
    gh-pages -d "$BUILD_DIR" -b gh-pages --dotfiles 2>/dev/null
    DEPLOY_STATUS=$?
fi

if [ $DEPLOY_STATUS -ne 0 ]; then
    error "GitHub Pages deployment failed"
    exit 1
fi

success "GitHub Pages deployed"

##############################
# ENABLE PAGES
##############################

if [ "$GH_AVAILABLE" = true ]; then
    log "Enabling GitHub Pages..."
    
    sleep 3
    
    gh api \
        -X POST \
        "repos/$USERNAME/$PROJECT_NAME/pages" \
        -f source[branch]="gh-pages" \
        -f source[path]="/" 2>/dev/null
    
    if [ $? -ne 0 ]; then
        warn "Pages API call failed - may need to enable manually"
    fi
fi

##############################
# VERIFY BRANCH
##############################

sleep 2
git fetch origin --prune 2>/dev/null

git branch -r | grep "gh-pages" >/dev/null 2>&1

if [ $? -ne 0 ]; then
    warn "gh-pages branch not found yet (may take a moment)"
else
    success "gh-pages branch detected"
fi

##############################
# FINAL URL
##############################

FINAL_URL="https://$USERNAME.github.io/$PROJECT_NAME"

echo ""
echo "======================================"
echo " WEBSITE ONLINE"
echo "======================================"
echo ""
echo -e "${GREEN}URL:${NC} $FINAL_URL"
echo ""
success "Deployment completed"
echo ""
echo "📌 Important Notes:"
echo "   • GitHub Pages may take 1-5 minutes to go live"
echo "   • Check status at: https://github.com/$USERNAME/$PROJECT_NAME/settings/pages"
echo "   • For custom domain, add a CNAME file to your build directory"
echo ""