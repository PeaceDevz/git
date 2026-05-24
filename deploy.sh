#!/data/data/com.termux/files/usr/bin/bash

#############################################################
# GitHub Pages DEPLOY - NO NPMS IMPLE METHOD
#############################################################

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

clear
echo "======================================"
echo " GitHub Pages Deploy (Simple Method)"
echo "======================================"

##############################
# FIX GIT SAFE DIRECTORY
##############################
git config --global --add safe.directory "$PWD" 2>/dev/null
git config --global safe.directory "*" 2>/dev/null

##############################
# GET GITHUB USERNAME
##############################
if command -v gh >/dev/null 2>&1; then
    gh auth status >/dev/null 2>&1 || gh auth login --web
    USERNAME=$(gh api user -q .login 2>/dev/null)
fi

if [ -z "$USERNAME" ]; then
    read -p "Enter your GitHub username: " USERNAME
fi

if [ -z "$USERNAME" ]; then
    error "Username required"
    exit 1
fi

PROJECT_NAME=$(basename "$PWD")
success "User: $USERNAME"
log "Project: $PROJECT_NAME"

##############################
# CHECK FOR index.html
##############################
if [ ! -f "index.html" ]; then
    error "index.html not found in current directory"
    exit 1
fi

success "index.html found"

##############################
# SETUP GIT
##############################
git config --global user.name "$USERNAME"
git config --global user.email "$USERNAME@users.noreply.github.com"

# Initialize git if needed
if [ ! -d ".git" ]; then
    log "Initializing git repository..."
    git init
fi

# Create/switch to main branch
git checkout -B main 2>/dev/null

##############################
# CREATE .nojekyll
##############################
touch .nojekyll
log "Created .nojekyll"

##############################
# COMMIT ALL FILES
##############################
git add .

if [ -n "$(git status --porcelain)" ]; then
    log "Committing files..."
    git commit -m "Initial commit: $(date '+%Y-%m-%d %H:%M:%S')"
    success "Files committed"
else
    warn "No changes to commit"
fi

##############################
# SETUP GITHUB REMOTE
##############################
REMOTE_URL="https://github.com/$USERNAME/$PROJECT_NAME.git"

if ! git remote get-url origin >/dev/null 2>&1; then
    log "Adding remote origin..."
    git remote add origin "$REMOTE_URL"
else
    log "Remote origin already exists"
fi

##############################
# CREATE REPOSITORY ON GITHUB
##############################
if command -v gh >/dev/null 2>&1; then
    log "Creating repository on GitHub..."
    gh repo create "$PROJECT_NAME" --public --description "GitHub Pages site" 2>/dev/null
fi

##############################
# PUSH TO MAIN BRANCH
##############################
log "Pushing to main branch..."
git push -u origin main --force 2>/dev/null

if [ $? -eq 0 ]; then
    success "Pushed to main branch"
else
    error "Push failed. Make sure the repository exists:"
    echo "  https://github.com/$USERNAME/$PROJECT_NAME"
    echo ""
    read -p "Press Enter after creating the repository manually..."
    git push -u origin main --force
fi

##############################
# DEPLOY TO GH-PAGES BRANCH (MANUAL)
##############################
log "Deploying to gh-pages branch..."

# Create a temporary directory for the gh-pages branch
TEMP_DIR=$(mktemp -d)
cp -r ./* "$TEMP_DIR/" 2>/dev/null
cp -r ./.nojekyll "$TEMP_DIR/" 2>/dev/null

# Save current branch
CURRENT_BRANCH=$(git branch --show-current)

# Switch to gh-pages branch
git checkout --orphan gh-pages 2>/dev/null || git checkout gh-pages 2>/dev/null

# Remove all files
git rm -rf . 2>/dev/null

# Copy files from temp directory
cp -r "$TEMP_DIR"/* . 2>/dev/null
cp -r "$TEMP_DIR"/.[!.]* . 2>/dev/null

# Add and commit
git add .
git commit -m "Deploy to GitHub Pages: $(date '+%Y-%m-%d %H:%M:%S')" 2>/dev/null

if [ $? -eq 0 ]; then
    # Push gh-pages branch
    git push origin gh-pages --force
    
    if [ $? -eq 0 ]; then
        success "Deployed to gh-pages branch"
    else
        error "Failed to push gh-pages branch"
    fi
else
    warn "No changes to commit on gh-pages"
fi

# Clean up temp directory
rm -rf "$TEMP_DIR"

# Switch back to main branch
git checkout "$CURRENT_BRANCH" 2>/dev/null

##############################
# ENABLE GITHUB PAGES
##############################
if command -v gh >/dev/null 2>&1; then
    log "Enabling GitHub Pages..."
    sleep 2
    gh api -X POST "repos/$USERNAME/$PROJECT_NAME/pages" \
        -f source[branch]="gh-pages" \
        -f source[path]="/" 2>/dev/null
fi

##############################
# DISPLAY URL
##############################
FINAL_URL="https://$USERNAME.github.io/$PROJECT_NAME"

echo ""
echo "======================================"
echo "✅ DEPLOYMENT COMPLETE!"
echo "======================================"
echo ""
echo "🌐 Website URL: $FINAL_URL"
echo ""
echo "📊 Check status: https://github.com/$USERNAME/$PROJECT_NAME/settings/pages"
echo ""
echo "⏱️  Note: It may take 1-5 minutes for the site to go live"
echo ""