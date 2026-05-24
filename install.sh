# ================================
# FILE: install.sh
# ================================
#!/data/data/com.termux/files/usr/bin/bash

clear

echo "======================================"
echo " GitHub Pages Auto Deploy Installer"
echo " Android Termux Setup"
echo "======================================"

pkg update -y && pkg upgrade -y

echo ""
echo "[1/6] Installing git..."
pkg install git -y

echo ""
echo "[2/6] Installing nodejs..."
pkg install nodejs -y

echo ""
echo "[3/6] Installing gh (GitHub CLI)..."
pkg install gh -y

echo ""
echo "[4/6] Installing openssh..."
pkg install openssh -y

echo ""
echo "[5/6] Installing gh-pages package..."
npm install -g gh-pages

echo ""
echo "[6/6] Setup storage permission..."
termux-setup-storage

echo ""
echo "======================================"
echo " Installed Versions"
echo "======================================"

git --version
node -v
npm -v
gh --version

echo ""
echo "======================================"
echo " Login GitHub"
echo "======================================"

gh auth status >/dev/null 2>&1

if [ $? -ne 0 ]; then
    echo ""
    echo "GitHub login required..."
    echo ""

    gh auth login --web --git-protocol https

    if [ $? -ne 0 ]; then
        echo ""
        echo "[ERROR] GitHub login failed."
        exit 1
    fi
else
    echo "GitHub already logged in."
fi

echo ""
echo "======================================"
echo " Setup Complete"
echo "======================================"

echo ""
echo "Next:"
echo "Put deploy.sh inside your website folder"
echo "Then run:"
echo ""
echo "bash deploy.sh"
echo ""