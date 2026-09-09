#!/bin/bash
# =============================================================================
#  Jobs Monitor — Builder & Installer
#  Built by Arun Thomas · https://github.com/arunofhyd/JobsMonitor
#
#  This fetches the latest source code from GitHub and compiles Jobs Monitor
#  LOCALLY on your Mac into your Applications folder.
#  100% Native, 100% Private, zero telemetry.
# =============================================================================

APP_NAME="JobsMonitor"
PLIST_LABEL="com.aoh.jobsmonitor"
MAIN_SWIFT_URL="https://raw.githubusercontent.com/arunofhyd/JobsMonitor/main/main.swift"
LOGO_PNG_URL="https://raw.githubusercontent.com/arunofhyd/JobsMonitor/main/logo-jobsmonitor.png"
APP_ICON_ICNS_URL="https://raw.githubusercontent.com/arunofhyd/JobsMonitor/main/AppIcon.icns"
APP_ICON_PNG_URL="https://raw.githubusercontent.com/arunofhyd/JobsMonitor/main/AppIcon.png"

# Terminal Colors & Formatting
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
WHITE='\033[1;37m'
GREY='\033[0;90m'
NC='\033[0m'
BOLD='\033[1m'

step() { printf "  ${BLUE}➔${NC} %s\n" "$1"; }
ok()   { printf "  ${GREEN}✔${NC} %s\n" "$1"; }
fail() { printf "  ${RED}✖${NC} %s\n" "$1"; }
line() { printf "${GREY}─────────────────────────────────────────────────────────────${NC}\n"; }

clear 2>/dev/null || true
printf "\n"
line
printf "${WHITE}${BOLD}    Jobs Monitor Installer${NC}\n"
line
printf "\n"

# ---- Step 1: Pre-flight Checks --------------------------------------------
step "Checking system prerequisites…"
if ! command -v swiftc >/dev/null 2>&1; then
    fail "Swift compiler (swiftc) not found."
    printf "\n  ${GREY}Triggering Xcode Command Line Tools installation…${NC}\n"
    xcode-select --install >/dev/null 2>&1 || true
    printf "  ${GREY}Please complete the Apple installer prompt and re-run this command.${NC}\n\n"
    exit 1
fi
ok "Prerequisites verified."
printf "\n"

# ---- Step 2: Workspace & Fetch Source --------------------------------------
step "Preparing temporary build workspace…"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT

if [ -f "$SCRIPT_DIR/main.swift" ]; then
    step "Using local source code from repository…"
    cp "$SCRIPT_DIR/main.swift" "$BUILD_DIR/main.swift"
    [ -f "$SCRIPT_DIR/logo-jobsmonitor.png" ] && cp "$SCRIPT_DIR/logo-jobsmonitor.png" "$BUILD_DIR/logo-jobsmonitor.png"
    [ -f "$SCRIPT_DIR/AppIcon.icns" ] && cp "$SCRIPT_DIR/AppIcon.icns" "$BUILD_DIR/AppIcon.icns"
    [ -f "$SCRIPT_DIR/AppIcon.png" ] && cp "$SCRIPT_DIR/AppIcon.png" "$BUILD_DIR/AppIcon.png"
else
    step "Fetching latest source code from GitHub…"
    if ! curl -sSL "$MAIN_SWIFT_URL" -o "$BUILD_DIR/main.swift"; then
        fail "Could not fetch main.swift from GitHub. Please check your internet connection."
        exit 1
    fi
    curl -sSL "$APP_ICON_ICNS_URL" -o "$BUILD_DIR/AppIcon.icns" 2>/dev/null || true
    curl -sSL "$APP_ICON_PNG_URL" -o "$BUILD_DIR/AppIcon.png" 2>/dev/null || true
    curl -sSL "$LOGO_PNG_URL" -o "$BUILD_DIR/logo-jobsmonitor.png" 2>/dev/null || true
    curl -sSL "$VERSION_CHECK_URL" -o "$BUILD_DIR/version.json" 2>/dev/null || true
fi

# Dynamically extract version from version.json as single source of truth
APP_VERSION=""
if [ -f "$BUILD_DIR/version.json" ]; then
    APP_VERSION=$(python3 -c "import json; print(json.load(open('$BUILD_DIR/version.json'))['version'])" 2>/dev/null || true)
elif [ -f "$SCRIPT_DIR/version.json" ]; then
    APP_VERSION=$(python3 -c "import json; print(json.load(open('$SCRIPT_DIR/version.json'))['version'])" 2>/dev/null || true)
fi
if [ -z "$APP_VERSION" ]; then
    APP_VERSION="$(grep -m1 'APP_VERSION' "$BUILD_DIR/main.swift" 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1 || true)"
fi
if [ -z "$APP_VERSION" ]; then
    APP_VERSION="2.3.5"
fi

ok "Source code and assets prepared (v${APP_VERSION})."
printf "\n"

# ---- Step 3: Compiling the app -------------------------------------------
step "Compiling Jobs Monitor v${APP_VERSION}…"
COMPILE_ERR="$(mktemp)"
if ! swiftc -O "$BUILD_DIR/main.swift" -o "$BUILD_DIR/$APP_NAME" -framework AppKit -framework ServiceManagement -framework UserNotifications -framework SwiftUI -framework Foundation -framework WebKit -framework AVFoundation 2>"$COMPILE_ERR"; then
    fail "Could not compile the application locally."
    printf "  ${GREY}Falling back to downloading pre-built release...${NC}\n"
    rm -f "$COMPILE_ERR"

    ZIP_URL="https://github.com/arunofhyd/JobsMonitor/releases/download/v${APP_VERSION}/JobsMonitor.zip"
    if ! curl -fsSL "$ZIP_URL" -o "$BUILD_DIR/JobsMonitor.zip"; then
        ZIP_URL="https://github.com/arunofhyd/JobsMonitor/releases/latest/download/JobsMonitor.zip"
        curl -fsSL "$ZIP_URL" -o "$BUILD_DIR/JobsMonitor.zip" || { fail "Download failed."; exit 1; }
    fi

    rm -rf "$BUILD_DIR/$APP_NAME.app"
    unzip -o -q "$BUILD_DIR/JobsMonitor.zip" -d "$BUILD_DIR"
    ok "Pre-built app downloaded successfully."
    PREBUILT_DOWNLOADED=true
else
    rm -f "$COMPILE_ERR"
    ok "App compiled successfully."
    PREBUILT_DOWNLOADED=false
fi
printf "\n"

# ---- Step 4: Building app bundle & app icon -------------------------------
if [ "$1" = "--ci" ] || [ "$CI" = "true" ]; then
    BUILD_DIR_LOCAL="$SCRIPT_DIR/Build"
    mkdir -p "$BUILD_DIR_LOCAL"
    TARGET_APP="$BUILD_DIR_LOCAL/$APP_NAME.app"
else
    TARGET_APP="/Applications/$APP_NAME.app"
    pkill -x "$APP_NAME" 2>/dev/null || true
fi
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"

if [ "$PREBUILT_DOWNLOADED" != "true" ]; then
    step "Building app bundle & app icon…"
    rm -rf "$APP_BUNDLE"
    mkdir -p "$APP_BUNDLE/Contents/MacOS"
    mkdir -p "$APP_BUNDLE/Contents/Resources"

    cp "$BUILD_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
    chmod 755 "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

    [ -f "$BUILD_DIR/AppIcon.icns" ] && cp "$BUILD_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
    [ -f "$BUILD_DIR/AppIcon.png" ] && cp "$BUILD_DIR/AppIcon.png" "$APP_BUNDLE/Contents/Resources/AppIcon.png"
    [ -f "$BUILD_DIR/logo-jobsmonitor.png" ] && cp "$BUILD_DIR/logo-jobsmonitor.png" "$APP_BUNDLE/Contents/Resources/logo-jobsmonitor.png"
    if [ ! -f "$APP_BUNDLE/Contents/Resources/AppIcon.png" ] && [ -f "$BUILD_DIR/logo-jobsmonitor.png" ]; then
        cp "$BUILD_DIR/logo-jobsmonitor.png" "$APP_BUNDLE/Contents/Resources/AppIcon.png"
    fi

    cat << EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://Apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$PLIST_LABEL</string>
    <key>CFBundleName</key>
    <string>Jobs Monitor</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$APP_VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
EOF

    codesign --force --deep --sign - --requirements '=designated => identifier "'"$PLIST_LABEL"'"' "$APP_BUNDLE" >/dev/null 2>&1 || true
    xattr -dr com.apple.quarantine "$APP_BUNDLE" >/dev/null 2>&1 || true
    ok "App bundle created."
    printf "\n"
fi

if [ "$1" = "--ci" ] || [ "$CI" = "true" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    mkdir -p "$SCRIPT_DIR/Build"
    cp -R "$APP_BUNDLE" "$SCRIPT_DIR/Build/"
    ok "CI mode detected. App copied to Build/$APP_NAME.app"
    exit 0
fi

# ---- Step 5: Install to /Applications & setup LaunchAgent ----------------
step "Installing Jobs Monitor to /Applications…"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
TARGET_APP="/Applications/$APP_NAME.app"
INSTALLED=false

if [ "$FORCE_MODAL" = "1" ] || [ "$1" = "--modal" ] || [ "$1" = "--gui" ] || [ "$2" = "--modal" ]; then
    INSTALLED=false
elif [ -w "/Applications" ]; then
    rm -rf "$TARGET_APP" 2>/dev/null || true
    if cp -R "$APP_BUNDLE" "$TARGET_APP" 2>/dev/null; then
        INSTALLED=true
    fi
fi

setup_launch_agent() {
    LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
    mkdir -p "$LAUNCH_AGENTS_DIR"
    PLIST_PATH="$LAUNCH_AGENTS_DIR/$PLIST_LABEL.plist"
    cat << EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>$PLIST_LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$TARGET_APP/Contents/MacOS/$APP_NAME</string>
    </array>
    <key>RunAtLoad</key><true/>
    <key>KeepAlive</key><false/>
</dict>
</plist>
EOF
    defaults delete "$PLIST_LABEL" has_launched_jobsmonitor 2>/dev/null || true
    pkill -9 -x "$APP_NAME" 2>/dev/null || true
    launchctl unload "$PLIST_PATH" 2>/dev/null || true
    launchctl load "$PLIST_PATH" 2>/dev/null || true
    touch "$TARGET_APP"
    open "$TARGET_APP" --args --open-preferences
}

if [ "$INSTALLED" = "true" ]; then
    xattr -dr com.apple.quarantine "$TARGET_APP" >/dev/null 2>&1 || true
    setup_launch_agent
    ok "Jobs Monitor installed & running."
    printf "\n"
    line
    printf "${WHITE}${BOLD}   ✓ Jobs Monitor is installed and running in your menu bar.${NC}\n"
    line
    printf "\n"
    exit 0
fi

# Fallback: Open Drag Modal if elevated permission required
printf "  ➔ Standard install required elevated privileges. Opening installer modal…\n"
cat > Installer.swift <<'INSTEOF'
import Cocoa
import QuartzCore

let appName = "Jobs Monitor"
let sourcePath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ""

func performInstallation(src: URL) -> Bool {
    let dest = URL(fileURLWithPath: "/Applications").appendingPathComponent("Jobs Monitor.app")
    do {
        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: src, to: dest)
    } catch {
        let script = "do shell script \"rm -rf '/Applications/Jobs Monitor.app'; cp -R '\(src.path)' '/Applications/Jobs Monitor.app'\" with administrator privileges"
        if let s = NSAppleScript(source: script) {
            var err: NSDictionary?
            s.executeAndReturnError(&err)
            if err != nil { return false }
        }
    }
    let clean = Process()
    clean.launchPath = "/usr/bin/xattr"
    clean.arguments = ["-dr", "com.apple.quarantine", dest.path]
    clean.standardOutput = Pipe(); clean.standardError = Pipe()
    try? clean.run(); clean.waitUntilExit()

    NSSound(named: "Glass")?.play()
    NSWorkspace.shared.open(dest)
    NSApp.terminate(nil)
    return true
}

class ActionTarget: NSObject {
    @objc static func oneClickInstall() {
        if !sourcePath.isEmpty {
            let src = URL(fileURLWithPath: sourcePath)
            _ = performInstallation(src: src)
        }
    }
}

class DragIcon: NSImageView, NSDraggingSource {
    var fileURL: URL?
    func draggingSession(_ s: NSDraggingSession, sourceOperationMaskFor c: NSDraggingContext) -> NSDragOperation { .copy }
    override func mouseDown(with event: NSEvent) {
        guard let url = fileURL, let originalImg = image else { return }
        let item = NSPasteboardItem()
        item.setString(url.absoluteString, forType: .fileURL)
        let drag = NSDraggingItem(pasteboardWriter: item)
        let dragImg = NSImage(size: bounds.size)
        dragImg.lockFocus()
        if let ctx = NSGraphicsContext.current { ctx.imageInterpolation = .high }
        originalImg.draw(in: bounds)
        dragImg.unlockFocus()
        drag.setDraggingFrame(bounds, contents: dragImg)
        beginDraggingSession(with: [drag], event: event, source: self)
    }
}

class DropZone: NSImageView {
    override init(frame f: NSRect) { super.init(frame: f); registerForDraggedTypes([.fileURL]) }
    required init?(coder: NSCoder) { super.init(coder: coder); registerForDraggedTypes([.fileURL]) }
    override func draggingEntered(_ s: NSDraggingInfo) -> NSDragOperation { .copy }
    override func performDragOperation(_ s: NSDraggingInfo) -> Bool {
        guard let str = s.draggingPasteboard.propertyList(forType: .fileURL) as? String,
              let src = URL(string: str) else { return false }
        return performInstallation(src: src)
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let W: CGFloat = 620, H: CGFloat = 410
let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: W, height: H), styleMask: [.titled, .closable], backing: .buffered, defer: false)
win.title = "Install Jobs Monitor"
win.center()

let bg = NSVisualEffectView(frame: NSRect(x: 0, y: 0, width: W, height: H))
bg.material = .windowBackground; bg.state = .active
win.contentView = bg

let title = NSTextField(labelWithString: "Install Jobs Monitor")
title.frame = NSRect(x: 0, y: H - 65, width: W, height: 30)
title.alignment = .center
title.font = NSFont.systemFont(ofSize: 22, weight: .bold)
bg.addSubview(title)

let sub = NSTextField(labelWithString: "Drag Jobs Monitor to Applications or click Instant Install below")
sub.frame = NSRect(x: 0, y: H - 90, width: W, height: 20)
sub.alignment = .center
sub.font = NSFont.systemFont(ofSize: 13)
sub.textColor = .secondaryLabelColor
bg.addSubview(sub)

let iconSize: CGFloat = 128, midY: CGFloat = 145
let appIcon = DragIcon(frame: NSRect(x: 90, y: midY, width: iconSize, height: iconSize))
appIcon.imageScaling = .scaleProportionallyUpOrDown

var loadedAppIcon: NSImage?
let resourcesDir = URL(fileURLWithPath: sourcePath).appendingPathComponent("Contents/Resources")
for name in ["AppIcon.png", "logo-jobsmonitor.png", "AppIcon.icns"] {
    let iconPath = resourcesDir.appendingPathComponent(name).path
    if FileManager.default.fileExists(atPath: iconPath), let img = NSImage(contentsOfFile: iconPath) {
        loadedAppIcon = img
        break
    }
}
if loadedAppIcon == nil {
    loadedAppIcon = NSWorkspace.shared.icon(forFile: sourcePath)
}
loadedAppIcon?.size = NSSize(width: iconSize, height: iconSize)
appIcon.image = loadedAppIcon
appIcon.fileURL = URL(fileURLWithPath: sourcePath)
bg.addSubview(appIcon)

let appLabel = NSTextField(labelWithString: appName)
appLabel.frame = NSRect(x: 90, y: midY - 26, width: iconSize, height: 18)
appLabel.alignment = .center
appLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
bg.addSubview(appLabel)

// Gradient Arrow View (Fading Stem Arrow)
class GradientArrowView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let w = bounds.width
        let h = bounds.height
        let midY = h / 2.0
        
        let stemH: CGFloat = 10
        let headH: CGFloat = 26
        let headW: CGFloat = 20
        let stemR = w - headW
        
        let path = NSBezierPath()
        path.move(to: NSPoint(x: 0, y: midY - stemH/2))
        path.line(to: NSPoint(x: stemR, y: midY - stemH/2))
        path.line(to: NSPoint(x: stemR, y: midY - headH/2))
        path.line(to: NSPoint(x: w, y: midY))
        path.line(to: NSPoint(x: stemR, y: midY + headH/2))
        path.line(to: NSPoint(x: stemR, y: midY + stemH/2))
        path.line(to: NSPoint(x: 0, y: midY + stemH/2))
        path.close()
        
        let startColor = NSColor.labelColor.withAlphaComponent(0.0)
        let endColor = NSColor.labelColor.withAlphaComponent(0.50)
        let gradient = NSGradient(starting: startColor, ending: endColor)
        gradient?.draw(in: path, angle: 0)
    }
}

let arrow = GradientArrowView(frame: NSRect(x: (W - 70)/2, y: midY + iconSize/2 - 18, width: 70, height: 36))
bg.addSubview(arrow)

let drop = DropZone(frame: NSRect(x: W - 90 - iconSize, y: midY, width: iconSize, height: iconSize))
drop.imageScaling = .scaleProportionallyUpOrDown
let appsIcon = NSWorkspace.shared.icon(forFile: "/Applications")
appsIcon.size = NSSize(width: 128, height: 128)
drop.image = appsIcon
bg.addSubview(drop)

let appsLabel = NSTextField(labelWithString: "Applications")
appsLabel.frame = NSRect(x: W - 90 - iconSize, y: midY - 26, width: iconSize, height: 18)
appsLabel.alignment = .center
appsLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
bg.addSubview(appsLabel)

class AnimatedInstallButton: NSButton {
    private var trackingArea: NSTrackingArea?
    private var isHovered = false { didSet { animateState() } }
    private var isPressed = false { didSet { animateState() } }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    private func setup() {
        wantsLayer = true
        isBordered = false
        focusRingType = .none
        layer?.cornerRadius = 10
        layer?.backgroundColor = NSColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0).cgColor
        contentTintColor = .white
    }
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = trackingArea { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(area)
        trackingArea = area
    }
    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        NSCursor.pointingHand.set()
    }
    override func mouseExited(with event: NSEvent) {
        isHovered = false
        NSCursor.arrow.set()
    }
    override func mouseDown(with event: NSEvent) {
        isPressed = true
        super.mouseDown(with: event)
    }
    override func mouseUp(with event: NSEvent) {
        isPressed = false
        super.mouseUp(with: event)
    }
    private func animateState() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            ctx.allowsImplicitAnimation = true
            if isPressed {
                layer?.backgroundColor = NSColor(red: 0.14, green: 0.14, blue: 0.16, alpha: 1.0).cgColor
                layer?.transform = CATransform3DMakeScale(0.95, 0.95, 1.0)
            } else if isHovered {
                layer?.backgroundColor = NSColor(red: 0.28, green: 0.28, blue: 0.30, alpha: 1.0).cgColor
                layer?.transform = CATransform3DMakeScale(1.04, 1.04, 1.0)
                layer?.shadowColor = NSColor.black.cgColor
                layer?.shadowRadius = 8
                layer?.shadowOpacity = 0.35
                layer?.shadowOffset = .zero
            } else {
                layer?.backgroundColor = NSColor(red: 0.18, green: 0.18, blue: 0.20, alpha: 1.0).cgColor
                layer?.transform = CATransform3DIdentity
                layer?.shadowOpacity = 0
            }
        }
    }
}

let installBtn = AnimatedInstallButton(frame: NSRect(x: (W - 270)/2, y: 35, width: 270, height: 42))
installBtn.title = "⚡ One-Click Install to /Applications"
installBtn.font = NSFont.systemFont(ofSize: 13, weight: .bold)
installBtn.target = ActionTarget.self
installBtn.action = #selector(ActionTarget.oneClickInstall)
bg.addSubview(installBtn)

win.makeKeyAndOrderFront(nil)
app.activate(ignoringOtherApps: true)
app.run()
INSTEOF

if swiftc -O -o Installer Installer.swift -framework Cocoa >/dev/null 2>&1; then
    ./Installer "$APP_BUNDLE"
fi
setup_launch_agent
printf "\n"
