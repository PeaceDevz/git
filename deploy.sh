#!/data/data/com.termux/files/usr/bin/bash

#########################################################
# GitHub Pages FULL AUTO DEPLOY
# Android Termux Compatible
#########################################################

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
# LOG FUNCTIONS
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
# START
##############################

clear

echo "======================================"
echo " GitHub Pages Auto Deploy"
echo " Android Termux"
echo "======================================"

##############################
# CHECK COMMANDS
##############################

check_command() {
    command -v "$1" >/dev/null 2>&1
}

if ! check_command git; then
    error "git not installed"
    echo "Run: pkg install git -y"
    exit 1
fi

if ! check_command node; then
    error "nodejs not installed"
    echo "Run: pkg install nodejs -y"
    exit 1
fi

if ! check_command npm; then
    error "npm not installed"
    exit 1
fi

if ! check_command gh; then
    error "GitHub CLI not installed"
    echo "Run: pkg install gh -y"
    exit 1
fi

success "All dependencies available"

##############################
# CHECK GITHUB LOGIN
##############################

log "Checking GitHub authentication..."

gh auth status >/dev/null 2>&1

if [ $? -ne 0 ]; then

    warn "GitHub not logged in"

    echo ""
    echo "Opening GitHub login..."
    echo ""

    gh auth login --web --git-protocol https

    if [ $? -ne 0 ]; then
        error "GitHub login failed"
        exit 1
    fi
fi

success "GitHub authenticated"

##############################
# AUTO GIT CONFIG
##############################

USERNAME=$(gh api user -q .login)

if [ -z "$USERNAME" ]; then
    error "Cannot get GitHub username"
    exit 1
fi

git config --global user.name "$USERNAME"
git config --global user.email "$USERNAME@users.noreply.github.com"

success "Git configured"

##############################
# PROJECT INFO
##############################

PROJECT_NAME=$(basename "$PWD")

echo ""
log "Project detected: $PROJECT_NAME"

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

    else

        PROJECT_TYPE="node"
        BUILD_DIR="dist"

    fi
fi

success "Project type: $PROJECT_TYPE"

##############################
# INSTALL DEPENDENCIES
##############################

if [ "$PROJECT_TYPE" != "static" ]; then

    log "Installing npm dependencies..."

    npm install

    if [ $? -ne 0 ]; then
        error "npm install failed"
        exit 1
    fi

    success "Dependencies installed"
fi

##############################
# BUILD PROJECT
##############################

if [ "$PROJECT_TYPE" != "static" ]; then

    log "Running production build..."

    npm run build

    if [ $? -ne 0 ]; then
        error "Build failed"
        exit 1
    fi

    success "Build successful"
fi

##############################
# VALIDATE BUILD
##############################

if [ ! -d "$BUILD_DIR" ]; then
    error "Build directory not found: $BUILD_DIR"
    exit 1
fi

success "Build directory ready"

##############################
# CREATE .nojekyll
##############################

touch "$BUILD_DIR/.nojekyll"

##############################
# GIT INIT
##############################

if [ ! -d ".git" ]; then

    log "Initializing git repository..."

    git init

    if [ $? -ne 0 ]; then
        error "git init failed"
        exit 1
    fi

    git branch -M $DEFAULT_BRANCH

    success "Git initialized"
fi

##############################
# CREATE .gitignore
##############################

if [ ! -f ".gitignore" ]; then

cat > .gitignore <<EOF
node_modules
dist
build
.cache
.vite
EOF

fi

##############################
# CREATE FIRST COMMIT
##############################

git add .

git commit -m "initial commit" >/dev/null 2>&1

##############################
# REMOTE CHECK
##############################

git remote get-url origin >/dev/null 2>&1

if [ $? -ne 0 ]; then

    log "Creating GitHub repository..."

    gh repo create "$PROJECT_NAME" \
        --public \
        --source=. \
        --remote=origin

    if [ $? -ne 0 ]; then
        error "Repository creation failed"
        exit 1
    fi

    success "Repository created"
else
    warn "Git remote already exists"
fi

##############################
# PUSH SOURCE
##############################

log "Uploading source code..."

git add .

git commit -m "update deploy" >/dev/null 2>&1

git push -u origin $DEFAULT_BRANCH --force

if [ $? -ne 0 ]; then
    error "Git push failed"
    exit 1
fi

success "Source uploaded"

##############################
# INSTALL gh-pages
##############################

npm list -g gh-pages >/dev/null 2>&1

if [ $? -ne 0 ]; then

    log "Installing gh-pages package..."

    npm install -g gh-pages

    if [ $? -ne 0 ]; then
        error "Failed installing gh-pages"
        exit 1
    fi
fi

##############################
# DEPLOY
##############################

log "Deploying website to GitHub Pages..."

npx gh-pages -d "$BUILD_DIR"

if [ $? -ne 0 ]; then
    error "GitHub Pages deploy failed"
    exit 1
fi

success "GitHub Pages deployed"

##############################
# ENABLE GITHUB PAGES
##############################

log "Enabling GitHub Pages..."

gh api \
  --method POST \
  -H "Accept: application/vnd.github+json" \
  "/repos/$USERNAME/$PROJECT_NAME/pages" \
  -f source[branch]="gh-pages" \
  -f source[path]="/" >/dev/null 2>&1

##############################
# WAIT
##############################

echo ""
log "Waiting GitHub Pages propagation..."
sleep 5

##############################
# FINAL URL
##############################

FINAL_URL="https://$USERNAME.github.io/$PROJECT_NAME"

echo ""
echo "======================================"
echo " WEBSITE SUCCESSFULLY DEPLOYED"
echo "======================================"
echo ""

echo "$FINAL_URL"

echo ""
success "Done"
echo ""