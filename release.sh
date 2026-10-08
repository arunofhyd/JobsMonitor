#!/bin/bash
set -euo pipefail

# =============================================================================
#  JobsMonitor — Interactive Release Helper Script for EngWeb & GitHub
# =============================================================================

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSP_URL="https://ist-ssp.apple.com/file/add"
GITHUB_RELEASES_URL="https://github.com/arunofhyd/JobsMonitor/releases/new"

# Colors
GREEN="\033[0;32m"
BLUE="\033[0;34m"
YELLOW="\033[1;33m"
BOLD="\033[1m"
NC="\033[0m"

echo -e "${BOLD}${BLUE}🚀 JobsMonitor Release Automation Helper${NC}\n"

# 1. Version input
if [ $# -ge 1 ]; then
    NEW_VERSION="$1"
else
    CURRENT_VERSION=$(python3 -c "import json; print(json.load(open('$DIR/version.json'))['version'])")
    echo -e "Current version: ${YELLOW}${CURRENT_VERSION}${NC}"
    read -rp "Enter new version (e.g. 2.3.6): " NEW_VERSION
fi

if [[ ! "$NEW_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "❌ Error: Version must be in format X.Y.Z (e.g. 2.3.6)"
    exit 1
fi

# 2. Release notes input
if [ $# -ge 2 ]; then
    NOTES="$2"
else
    echo -e "\nEnter brief release notes for v${NEW_VERSION} (or press Enter for default):"
    read -rp "> " NOTES
fi

if [ -z "$NOTES" ]; then
    NOTES="Official Apple EngWeb release with Hardened Runtime and standardized bundle ID com.apple.aoh.jobsmonitor."
fi

# 3. Update version.json
echo -e "\n${BLUE}📝 Updating version.json to v${NEW_VERSION}...${NC}"
python3 -c "
import json
from datetime import date
with open('$DIR/version.json', 'r') as f:
    d = json.load(f)
d['version'] = '$NEW_VERSION'
new_entry = {
    'version': '$NEW_VERSION',
    'date': date.today().isoformat(),
    'changes': ['$NOTES']
}
d.setdefault('changelog', []).insert(0, new_entry)
with open('$DIR/version.json', 'w') as f:
    json.dump(d, f, indent=2)
"

# 4. Build and package with build_app.sh
echo -e "\n${BLUE}🔨 Compiling & packaging JobsMonitor.zip...${NC}"
"$DIR/build_app.sh"

ZIP_PATH="$DIR/JobsMonitor.zip"
if [ ! -f "$ZIP_PATH" ]; then
    echo "❌ Error: JobsMonitor.zip was not generated!"
    exit 1
fi

# 5. Copy formatted release notes to macOS clipboard
RELEASE_NOTES_TEXT="# Jobs Monitor v${NEW_VERSION}

> Jobs Monitor is a lightweight, privacy-first native macOS application that tracks job postings on careers.apple.com and jobs.apple.com in real-time.

### 🚀 What's New
* ${NOTES}
* Standardized internal bundle identifier: \`com.apple.aoh.jobsmonitor\`.
* Hardened Runtime compliance with strict designated code signature verification.
* Dual-Channel tracking for both AppleConnect Internal postings and Public positions.
* Instant macOS system notifications, daily digest schedules, and interactive local dashboard.

### 📦 Installation
* **Option 1: Direct Download (EngWeb / Tools.Apple.com)**
  Download JobsMonitor.zip, unzip, and move JobsMonitor.app to /Applications.
* **Option 2: Terminal One-Liner**
  \`\`\`bash
  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/arunofhyd/JobsMonitor/main/install-jobsmonitor.command)\"
  \`\`\`"

echo "$RELEASE_NOTES_TEXT" | pbcopy
echo -e "📋 ${GREEN}Release notes copied to your clipboard (⌘V ready)!${NC}"

# 6. Reveal zip in Finder and open SSP in browser
echo -e "\n${BLUE}🌐 Opening Software Signing Portal & revealing JobsMonitor.zip in Finder...${NC}"
open -R "$ZIP_PATH"
open "$SSP_URL" 2>/dev/null || true

echo -e "\n${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Next Steps in Safari (Software Signing Portal):${NC}"
echo -e " 1. Select ${BOLD}JobsMonitor${NC} ➔ ${BOLD}Upload Build / New Submission${NC}."
echo -e " 2. Drag ${BOLD}JobsMonitor.zip${NC} (highlighted in Finder) into the portal."
echo -e " 3. Press ${BOLD}⌘V${NC} in the Release Notes box (already on clipboard!)."
echo -e " 4. Ensure ${BOLD}Gatekeeper${NC}, ${BOLD}Appcast${NC}, and ${BOLD}Post to IS&T Web${NC} are selected."
echo -e " 5. Click ${BOLD}Submit${NC}."
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

read -rp "Press [Enter] once SSP finishes signing and you download the signed asset..."

# 7. Open GitHub Releases page
echo -e "\n${BLUE}📦 Opening GitHub Releases page...${NC}"
open "$GITHUB_RELEASES_URL" 2>/dev/null || true

echo -e "\n${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Next Steps on GitHub:${NC}"
echo -e " 1. Tag: ${BOLD}v${NEW_VERSION}${NC} (Target: main)."
echo -e " 2. Title: ${BOLD}Jobs Monitor v${NEW_VERSION}${NC}."
echo -e " 3. Description: Press ${BOLD}⌘V${NC} to paste release notes."
echo -e " 4. Drag the ${BOLD}signed JobsMonitor.zip${NC} downloaded from SSP into Assets."
echo -e " 5. Click ${BOLD}Publish release${NC}."
echo -e "${BOLD}${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -e "${GREEN}✨ Release workflow complete!${NC}"
