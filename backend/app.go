// Package backend implements the core application engine for LeviLamina Server Manager.
// It bridges the Wails v2 frontend runtime with low-level Windows process supervision,
// RakNet engine telemetry, Bedrock addons, and the official LeviMC 'lip' package manager.
package backend

import (
	"archive/zip"
	"context"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"time"

	wailsruntime "github.com/wailsapp/wails/v2/pkg/runtime"

	"levilamina-server-manager/backend/activity"
	"levilamina-server-manager/backend/addons"
	"levilamina-server-manager/backend/backups"
	"levilamina-server-manager/backend/bedrinth"
	"levilamina-server-manager/backend/compatibility"
	"levilamina-server-manager/backend/database"
	"levilamina-server-manager/backend/extensions"
	"levilamina-server-manager/backend/levilamina"
	"levilamina-server-manager/backend/lip"
	"levilamina-server-manager/backend/models"
	"levilamina-server-manager/backend/mods"
	"levilamina-server-manager/backend/players"
	"levilamina-server-manager/backend/process"
	"levilamina-server-manager/backend/server"
	"levilamina-server-manager/backend/updates"
	"levilamina-server-manager/backend/worlds"
	"levilamina-server-manager/backend/xbox"
)

// App is the central application controller exposed to the Wails JavaScript frontend.
// It coordinates server profiles, process supervision, addons, backups, and metrics.
type App struct {
	ctx             context.Context
	db              *database.Database
	serverMgr       *server.ServerManager
	supervisor      *process.ProcessSupervisor
	monitor         *process.ProcessMonitor
	playerMgr       *players.PlayerManager
	modMgr          *mods.ModManager
	addonMgr        *addons.AddonManager
	addonAnalyzer   *addons.AddonAnalyzer
	addonInstall    *addons.AddonInstaller
	worldMgr        *worlds.WorldManager
	backupMgr       *backups.BackupManager
	compatEngine    *compatibility.CompatibilityEngine
	lipClient       *lip.LipClient
	llMgr           *levilamina.LeviLaminaManager
	setupEngine     *server.ServerSetupEngine
	bedrinthClient  *bedrinth.BedrinthClient
	updateEngine    *updates.UpdateCheckerEngine
	xboxMgr         *xbox.XboxManager
	extMgr          *extensions.ExtensionManager
	preflightEngine *server.PreflightEngine
	activityLogger  *activity.ActivityLogger
}

func NewApp() (*App, error) {
	db, err := database.NewDatabase()
	if err != nil {
		return nil, err
	}
	return NewAppWithDB(db)
}

func NewAppWithDB(db *database.Database) (*App, error) {
	lipClient := lip.NewLipClient()
	llMgr := levilamina.NewLeviLaminaManager(lipClient)
	supervisor := process.NewProcessSupervisor()
	monitor := process.NewProcessMonitor(supervisor)
	bedrinthClient := bedrinth.NewBedrinthClient(lipClient)
	modMgr := mods.NewModManager()
	home, _ := os.UserHomeDir()
	llsmDir := filepath.Join(home, ".llsm")
	xboxMgr := xbox.NewXboxManager(llsmDir)
	extMgr := extensions.NewExtensionManager(llsmDir)
	updateEngine := updates.NewUpdateCheckerEngine(db, bedrinthClient, lipClient, llMgr, modMgr)
	preflightEngine := server.NewPreflightEngine()
	activityLogger := activity.NewActivityLogger(llsmDir)

	app := &App{
		db:              db,
		serverMgr:       server.NewServerManager(db, lipClient, llMgr),
		supervisor:      supervisor,
		monitor:         monitor,
		playerMgr:       players.NewPlayerManager(),
		modMgr:          modMgr,
		addonMgr:        addons.NewAddonManager(),
		addonAnalyzer:   addons.NewAddonAnalyzer(),
		addonInstall:    addons.NewAddonInstaller(),
		worldMgr:        worlds.NewWorldManager(),
		backupMgr:       backups.NewBackupManager(),
		compatEngine:    compatibility.NewCompatibilityEngine(),
		lipClient:       lipClient,
		llMgr:           llMgr,
		setupEngine:     server.NewServerSetupEngine(lipClient),
		bedrinthClient:  bedrinthClient,
		updateEngine:    updateEngine,
		xboxMgr:         xboxMgr,
		extMgr:          extMgr,
		preflightEngine: preflightEngine,
		activityLogger:  activityLogger,
	}

	// Forward activity log events to frontend
	activityLogger.SetListener(func(line string) {
		if app.ctx != nil {
			wailsruntime.EventsEmit(app.ctx, "app:activity", line)
		}
	})

	// Forward console and status events to Wails frontend
	supervisor.AddOutputListener(func(line string) {
		if app.ctx != nil {
			wailsruntime.EventsEmit(app.ctx, "server:console", line)
		}
	})

	supervisor.AddStatusListener(func(status models.ServerStatus, exitCode int) {
		if status == models.StatusOnline {
			activityLogger.Log("SERVER", "Bedrock server is ONLINE (PID: %d).", supervisor.GetPID())
		} else if status == models.StatusOffline {
			activityLogger.Log("SERVER", "Bedrock server is OFFLINE.")
		} else if status == models.StatusCrashed {
			activityLogger.Log("SERVER", "Bedrock server process CRASHED (Exit code: %d).", exitCode)
		}

		if app.ctx != nil {
			wailsruntime.EventsEmit(app.ctx, "server:status", map[string]any{
				"status":   status,
				"exitCode": exitCode,
			})
		}
	})

	return app, nil
}

func (a *App) Startup(ctx context.Context) {
	a.ctx = ctx
}

// Shutdown is invoked by Wails when the application is closing or window is closed.
// It ensures that any running Minecraft Bedrock server is stopped cleanly.
func (a *App) Shutdown(ctx context.Context) {
	if a.supervisor != nil {
		_ = a.supervisor.Stop(ctx)
	}
	killMod := exec.Command("taskkill", "/F", "/IM", "bedrock_server_mod.exe", "/T")
	killMod.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000}
	_ = killMod.Run()

	killBds := exec.Command("taskkill", "/F", "/IM", "bedrock_server.exe", "/T")
	killBds.SysProcAttr = &syscall.SysProcAttr{HideWindow: true, CreationFlags: 0x08000000}
	_ = killBds.Run()

}

// ExitApp completely terminates the application and all child processes.
func (a *App) ExitApp() {
	if a.ctx != nil {
		a.Shutdown(a.ctx)
	}
	go func() {
		time.Sleep(100 * time.Millisecond)
		os.Exit(0)
	}()
}

// BringToFront restores and focuses the window. Called when a second instance is launched.
func (a *App) BringToFront() {
	if a.ctx == nil {
		return
	}
	wailsruntime.WindowUnminimise(a.ctx)
	wailsruntime.WindowShow(a.ctx)
}

func (a *App) ToggleFullscreen() bool {
	if a.ctx == nil {
		return false
	}
	if wailsruntime.WindowIsFullscreen(a.ctx) {
		wailsruntime.WindowUnfullscreen(a.ctx)
		return false
	}
	wailsruntime.WindowFullscreen(a.ctx)
	return true
}

// ----------------- Server Instance Management -----------------

func (a *App) syncServerProperties(s *models.Server) {
	if s == nil || s.Path == "" {
		return
	}
	if props, err := server.LoadProperties(s.Path); err == nil {
		modified := false

		// 1. Check and sanitize level-name
		lvl := strings.TrimSpace(props.Get("level-name", ""))
		if strings.EqualFold(lvl, "Bedrock level") || strings.EqualFold(s.ActiveWorld, "Bedrock level") || s.ActiveWorld == "" {
			// Find actual world folder from worlds/ directory
			realWorld := "World"
			entries, rErr := os.ReadDir(filepath.Join(s.Path, "worlds"))
			if rErr == nil {
				for _, e := range entries {
					if e.IsDir() && !strings.EqualFold(e.Name(), "Bedrock level") {
						realWorld = e.Name()
						break
					}
				}
			}
			s.ActiveWorld = realWorld
			props.Set("level-name", realWorld)
			_ = os.RemoveAll(filepath.Join(s.Path, "worlds", "Bedrock level"))
			modified = true
		} else if lvl != "" && lvl != s.ActiveWorld {
			s.ActiveWorld = lvl
			modified = true
		}

		// 2. Fix server-name if it got set to generic "Dedicated Server"
		sName := strings.TrimSpace(props.Get("server-name", ""))
		if strings.EqualFold(sName, "Dedicated Server") || strings.EqualFold(s.Name, "Dedicated Server") {
			folderName := filepath.Base(s.Path)
			if folderName != "" && !strings.EqualFold(folderName, "Dedicated Server") {
				s.Name = folderName
				props.Set("server-name", folderName)
				modified = true
			}
		} else if sName != "" && sName != s.Name {
			s.Name = sName
			modified = true
		}

		if pStr := strings.TrimSpace(props.Get("server-port", "")); pStr != "" {
			if p, err := strconv.Atoi(pStr); err == nil && p > 0 && p != s.Port {
				s.Port = p
				modified = true
			}
		}

		if modified {
			_ = props.Save()
			_ = a.db.SaveServer(*s)
		}
	}
}

// GetServers returns all registered Bedrock server instances, synchronizing
// their runtime configuration properties with disk state.
func (a *App) GetServers() []models.Server {
	rawServers := a.db.GetServers()
	validServers := make([]models.Server, 0, len(rawServers))
	for _, s := range rawServers {
		a.syncServerProperties(&s)
		validServers = append(validServers, s)
	}
	return validServers
}

// GetServer returns a single server profile by its unique ID.
func (a *App) GetServer(id string) *models.Server {
	s, ok := a.db.GetServer(id)
	if !ok {
		return nil
	}
	a.syncServerProperties(s)
	return s
}

// CreateServer provisions a new Bedrock server profile with LeviLamina or vanilla runtime.
func (a *App) CreateServer(opts server.CreateServerOptions) (*models.Server, error) {
	return a.serverMgr.CreateServer(opts)
}

// GetDefaultServerLocation returns a safe default path for a new server
func (a *App) GetDefaultServerLocation(serverName string) string {
	sanitized := sanitizeServerFolderName(serverName)
	if sanitized == "" {
		sanitized = "Server"
	}
	// Try C:\MinecraftServers if accessible on Windows
	cBase := `C:\MinecraftServers`
	if err := os.MkdirAll(cBase, 0755); err == nil {
		return filepath.Join(cBase, sanitized)
	}
	// Fallback to UserHomeDir/MinecraftServers
	if home, err := os.UserHomeDir(); err == nil && home != "" {
		return filepath.Join(home, "MinecraftServers", sanitized)
	}
	return filepath.Join(".", "MinecraftServers", sanitized)
}

// GetNextAvailablePort finds the next available UDP port for Bedrock (starting at 19132)
func (a *App) GetNextAvailablePort() int {
	usedPorts := make(map[int]bool)
	if a.db != nil {
		for _, s := range a.db.GetServers() {
			if s.Port > 0 {
				usedPorts[s.Port] = true
				usedPorts[s.Port+1] = true // IPv6 companion port
			}
		}
	}

	for p := 19132; p <= 65530; p += 2 {
		if usedPorts[p] {
			continue
		}
		// Test if locally bindable
		conn, err := net.ListenUDP("udp", &net.UDPAddr{IP: net.ParseIP("0.0.0.0"), Port: p})
		if err == nil {
			conn.Close()
			return p
		}
	}
	return 19132
}

func sanitizeServerFolderName(name string) string {
	var sb strings.Builder
	for _, r := range name {
		if (r >= 'a' && r <= 'z') || (r >= 'A' && r <= 'Z') || (r >= '0' && r <= '9') || r == '_' || r == '-' {
			sb.WriteRune(r)
		} else if r == ' ' {
			sb.WriteRune('_')
		}
	}
	res := strings.Trim(sb.String(), "_- ")
	if res == "" {
		return "Server"
	}
	return res
}

// ImportServer registers an existing BDS or LeviLamina server folder into LLSM.
func (a *App) ImportServer(path string) (*models.Server, error) {
	return a.serverMgr.ImportExistingServer(path)
}

// RescanServer inspects the server directory to update detected worlds, packs, and BDS versions.
func (a *App) RescanServer(id string) (*models.Server, error) {
	return a.serverMgr.RescanServer(id)
}

// DeleteServer removes a server from LLSM tracking and stops its process if active.
func (a *App) DeleteServer(id string) error {
	if a.db != nil {
		activeID := a.db.GetActiveServerID()
		if activeID == id && a.supervisor != nil {
			_ = a.StopServer(id)
		}
		return a.db.DeleteServer(id)
	}
	return nil
}

// GetActiveServer returns the currently selected server profile.
func (a *App) GetActiveServer() *models.Server {
	activeID := a.db.GetActiveServerID()
	if activeID != "" {
		s, ok := a.db.GetServer(activeID)
		if ok {
			a.syncServerProperties(s)
			return s
		}
	}

	servers := a.GetServers()
	if len(servers) > 0 {
		_ = a.db.SetActiveServerID(servers[0].ID)
		return &servers[0]
	}
	_ = a.db.SetActiveServerID("")
	return nil
}

// SetActiveServer changes the active server focus in application state.
func (a *App) SetActiveServer(id string) error {
	return a.db.SetActiveServerID(id)
}

// OpenFolder opens the specified filesystem path in Windows File Explorer.
func (a *App) OpenFolder(folderPath string) error {
	return a.serverMgr.OpenFolder(folderPath)
}

type ServerSetupStatus struct {
	HasBDS         bool `json:"hasBds"`
	HasLeviLamina  bool `json:"hasLeviLamina"`
	HasLip         bool `json:"hasLip"`
	IsReadyToStart bool `json:"isReadyToStart"`
}

func (a *App) CheckServerFiles(serverID string) (*ServerSetupStatus, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	hasBDS, hasLL := a.setupEngine.CheckServerFiles(s.Path)
	_, hasLip := a.lipClient.FindLipPath(s.Path)
	return &ServerSetupStatus{
		HasBDS:         hasBDS,
		HasLeviLamina:  hasLL,
		HasLip:         hasLip,
		IsReadyToStart: hasBDS || hasLL,
	}, nil
}

func (a *App) AutomateServerSetup(serverID string) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	progress := func(step, totalSteps, percent int, status string) {
		if a.ctx != nil {
			wailsruntime.EventsEmit(a.ctx, "server:setup_progress", map[string]any{
				"step":       step,
				"totalSteps": totalSteps,
				"percent":    percent,
				"status":     status,
			})
		}
	}

	err := a.setupEngine.AutomateServerSetup(ctx, s.Path, progress)
	if err == nil {
		// Ensure active world is preserved in server.properties and purge "Bedrock level"
		if s.ActiveWorld != "" && !strings.EqualFold(s.ActiveWorld, "Bedrock level") {
			_ = a.serverMgr.SetActiveWorld(serverID, s.ActiveWorld)
			_ = os.RemoveAll(filepath.Join(s.Path, "worlds", "Bedrock level"))
		}
		// Rescan server to update metadata
		_, _ = a.serverMgr.RescanServer(serverID)
	}
	return err
}

// GetServerIPs returns local loopback and verified active LAN/VPN IPv4 addresses
func (a *App) GetServerIPs() map[string]string {
	ips := map[string]string{
		"local": "127.0.0.1",
		"lan":   "127.0.0.1",
	}

	// 1. Try finding the primary outbound routed network interface
	conn, err := net.DialTimeout("udp", "8.8.8.8:80", 1*time.Second)
	if err == nil {
		localAddr, ok := conn.LocalAddr().(*net.UDPAddr)
		_ = conn.Close()
		if ok && localAddr.IP != nil {
			v4 := localAddr.IP.To4()
			if v4 != nil && !v4.IsLoopback() && !v4.IsLinkLocalUnicast() {
				ips["lan"] = v4.String()
			}
		}
	}

	// 2. Inspect active network interfaces for LAN and VPN adapters
	ifaces, err := net.Interfaces()
	if err == nil {
		var lanCandidates []string

		for _, iface := range ifaces {
			if iface.Flags&net.FlagUp == 0 || iface.Flags&net.FlagLoopback != 0 {
				continue
			}

			addrs, err := iface.Addrs()
			if err != nil {
				continue
			}

			ifaceNameLower := strings.ToLower(iface.Name)

			for _, addr := range addrs {
				ipNet, ok := addr.(*net.IPNet)
				if !ok || ipNet.IP == nil {
					continue
				}
				v4 := ipNet.IP.To4()
				if v4 == nil || v4.IsLoopback() || v4.IsLinkLocalUnicast() {
					continue
				}

				ipStr := v4.String()

				// Detect Radmin VPN, Hamachi, Tailscale, WireGuard
				if strings.Contains(ifaceNameLower, "radmin") ||
					strings.Contains(ifaceNameLower, "vpn") ||
					strings.Contains(ifaceNameLower, "hamachi") ||
					strings.Contains(ifaceNameLower, "tailscale") ||
					v4[0] == 26 {
					ips["vpn"] = ipStr
				} else if v4[0] == 10 || (v4[0] == 172 && v4[1] >= 16 && v4[1] <= 31) || (v4[0] == 192 && v4[1] == 168) {
					lanCandidates = append(lanCandidates, ipStr)
				}
			}
		}

		if ips["lan"] == "127.0.0.1" && len(lanCandidates) > 0 {
			ips["lan"] = lanCandidates[0]
		}
	}

	return ips
}

// ----------------- Process & Live Console -----------------

// StartServer launches the Bedrock server process under active supervisor tracking,
// performing pre-flight sanity checks and firewall validation.
func (a *App) StartServer(id string) error {
	s, ok := a.db.GetServer(id)
	if !ok {
		return fmt.Errorf("server not found: %s", id)
	}

	// Guard against "Bedrock level"
	if s.ActiveWorld == "" || strings.EqualFold(s.ActiveWorld, "Bedrock level") {
		// Inspect worlds folder to find real world
		targetWorld := "World"
		entries, err := os.ReadDir(filepath.Join(s.Path, "worlds"))
		if err == nil {
			for _, e := range entries {
				if e.IsDir() && !strings.EqualFold(e.Name(), "Bedrock level") {
					targetWorld = e.Name()
					break
				}
			}
		}
		s.ActiveWorld = targetWorld
		_ = a.db.SaveServer(*s)
	}

	// Always synchronize active world into server.properties before starting process
	if s.ActiveWorld != "" {
		_ = a.serverMgr.SetActiveWorld(id, s.ActiveWorld)
		if !strings.EqualFold(s.ActiveWorld, "Bedrock level") {
			_ = os.RemoveAll(filepath.Join(s.Path, "worlds", "Bedrock level"))
		}
	}

	// Automated Pre-flight Health Check & Auto-Repair before starting process
	// Automatically fixes UWP Loopback Exemption, Windows Firewall, ports, and configuration
	if a.preflightEngine != nil {
		report, _ := a.preflightEngine.RunPreflight(s.Path, func(p string) error {
			if a.addonInstall != nil {
				return a.addonInstall.SyncValidKnownPacks(p)
			}
			return nil
		})
		if report != nil {
			for _, fixed := range report.FixedIssues {
				if a.ctx != nil {
					wailsruntime.EventsEmit(a.ctx, "server:console", fmt.Sprintf("[Pre-Flight Auto-Fix] %s", fixed))
				}
			}
			for _, warn := range report.Warnings {
				if a.ctx != nil {
					wailsruntime.EventsEmit(a.ctx, "server:console", fmt.Sprintf("[Pre-Flight Warning] %s", warn))
				}
			}
		}
	}

	if a.activityLogger != nil {
		a.activityLogger.Log("SERVER", "Starting Bedrock server '%s'...", s.Name)
	}
	return a.supervisor.Start(s.Path, s.AutoRestart)
}

// FixNetworkAndJoinIssues manually diagnoses and fixes network, firewall, loopback, and config issues.
func (a *App) FixNetworkAndJoinIssues(serverID string) (*models.JoinHealthReport, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found: %s", serverID)
	}
	if a.preflightEngine == nil {
		a.preflightEngine = server.NewPreflightEngine()
	}
	return a.preflightEngine.RunPreflight(s.Path, func(p string) error {
		if a.addonInstall != nil {
			return a.addonInstall.SyncValidKnownPacks(p)
		}
		return nil
	})
}

// StopServer issues a graceful 'stop' command to the server and awaits shutdown.
func (a *App) StopServer(id string) error {
	if a.activityLogger != nil {
		a.activityLogger.Log("SERVER", "Stopping server...")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 12*time.Second)
	defer cancel()
	return a.supervisor.Stop(ctx)
}

// RestartServer gracefully shuts down the server and relaunches it.
func (a *App) RestartServer(id string) error {
	s, ok := a.db.GetServer(id)
	if !ok {
		return fmt.Errorf("server not found: %s", id)
	}
	if a.activityLogger != nil {
		a.activityLogger.Log("SERVER", "Restarting server '%s'...", s.Name)
	}
	ctx, cancel := context.WithTimeout(context.Background(), 12*time.Second)
	defer cancel()
	_ = a.supervisor.Stop(ctx)
	time.Sleep(1 * time.Second)
	return a.supervisor.Start(s.Path, s.AutoRestart)
}

// GetServerStatus returns the current execution state of the BDS supervisor.
func (a *App) GetServerStatus(id string) models.ServerStatus {
	return a.supervisor.GetStatus()
}

// GetServerMetrics returns real-time hardware utilization, dynamic TPS, and MSPT metrics.
func (a *App) GetServerMetrics(id string) models.ServerMetrics {
	return a.monitor.GetMetrics()
}

// SendConsoleCommand transmits a command string into BDS standard input.
func (a *App) SendConsoleCommand(id string, cmd string) error {
	return a.supervisor.SendCommand(cmd)
}

// GetConsoleLogs returns recently captured console log lines from the ring buffer.
func (a *App) GetConsoleLogs(id string) []string {
	return a.supervisor.GetRecentLogs()
}

// GetActivityLogs returns persistent audit events (server events, backups, marketplace).
func (a *App) GetActivityLogs() []string {
	if a.activityLogger == nil {
		return []string{}
	}
	return a.activityLogger.GetLogs()
}

// ClearActivityLogs purges the persistent activity log ring buffer.
func (a *App) ClearActivityLogs() error {
	if a.activityLogger == nil {
		return nil
	}
	return a.activityLogger.ClearLogs()
}

// ----------------- Server Properties -----------------

func (a *App) GetServerProperties(id string) (map[string]string, error) {
	s, ok := a.db.GetServer(id)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	sp, err := server.LoadProperties(s.Path)
	if err != nil {
		return nil, err
	}
	return sp.GetAll(), nil
}

func (a *App) SaveServerProperties(id string, props map[string]string) error {
	s, ok := a.db.GetServer(id)
	if !ok {
		return fmt.Errorf("server not found")
	}
	sp, err := server.LoadProperties(s.Path)
	if err != nil {
		return err
	}
	for k, v := range props {
		sp.Set(k, v)
	}
	if err := sp.Save(); err != nil {
		return err
	}
	// If level-name was updated, synchronize server record and world folder
	if levelName, exists := props["level-name"]; exists && levelName != "" {
		_ = a.serverMgr.SetActiveWorld(id, levelName)
	}
	return nil
}

// ----------------- LeviLamina Mods -----------------

func (a *App) ListMods(serverID string) ([]models.Mod, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	return a.modMgr.ListMods(s.Path)
}

func (a *App) EnableMod(modPath string) error {
	_, err := a.modMgr.EnableMod(modPath)
	return err
}

func (a *App) DisableMod(modPath string) error {
	_, err := a.modMgr.DisableMod(modPath)
	return err
}

func (a *App) RemoveMod(modPath string) error {
	return a.modMgr.RemoveMod(modPath)
}

func (a *App) GetModConfig(configPath string) (map[string]any, error) {
	return a.modMgr.ReadModConfig(configPath)
}

func (a *App) SaveModConfig(configPath string, cfg map[string]any) error {
	return a.modMgr.WriteModConfig(configPath, cfg)
}

// ----------------- LIP Integration -----------------

func (a *App) CheckLipStatus(serverID string) models.LipStatus {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return models.LipStatus{Installed: false, Version: "Server not found"}
	}
	lipPath, found := a.lipClient.FindLipPath(s.Path)
	if !found {
		return models.LipStatus{Installed: false, Version: "Not Installed"}
	}
	ver, err := a.lipClient.GetVersion(s.Path)
	if err != nil {
		return models.LipStatus{Installed: true, Version: "v0.34.8", BinaryPath: lipPath}
	}
	return models.LipStatus{Installed: true, Version: ver, BinaryPath: lipPath}
}

func (a *App) InstallLip() (string, error) {
	p, err := a.lipClient.InstallLipBinary()
	if err != nil {
		return "", err
	}
	// Copy to active server folder so both tools and server root have lip.exe
	if act := a.GetActiveServer(); act != nil && act.Path != "" {
		dest := filepath.Join(act.Path, "lip.exe")
		if data, readErr := os.ReadFile(p); readErr == nil {
			_ = os.WriteFile(dest, data, 0755)
		}
	}
	return p, nil
}

func (a *App) InstallLipPackage(serverID, pkgIdentifier string) (*lip.CommandResult, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	_ = os.MkdirAll(s.Path, 0755)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()
	return a.lipClient.InstallPackage(ctx, s.Path, pkgIdentifier)
}

func (a *App) UpdateLipPackage(serverID, pkgIdentifier string) (*lip.CommandResult, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	_ = os.MkdirAll(s.Path, 0755)
	ctx, cancel := context.WithTimeout(context.Background(), 3*time.Minute)
	defer cancel()
	return a.lipClient.UpdatePackage(ctx, s.Path, pkgIdentifier)
}

// ----------------- Bedrinth (pkg.levimc.org) Integration -----------------

func (a *App) GetBedrinthPackages() ([]models.BedrinthPackage, error) {
	return a.bedrinthClient.GetPackages()
}

func (a *App) InstallBedrinthPackage(serverID, tooth, version string) (*lip.CommandResult, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	_ = os.MkdirAll(s.Path, 0755)
	res, err := a.bedrinthClient.InstallPackage(s.Path, tooth, version)
	return &res, err
}

func (a *App) UninstallBedrinthPackage(serverID, tooth string) (*lip.CommandResult, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	res, err := a.bedrinthClient.UninstallPackage(s.Path, tooth)
	return &res, err
}

// ----------------- Add-On Analysis & Installation -----------------

// AnalyzeAddon inspects a .mcpack, .mcaddon, or zip archive and returns manifest metadata.
func (a *App) AnalyzeAddon(filePath string) (*models.AddonAnalysisResult, error) {
	return a.addonAnalyzer.AnalyzeArchive(filePath)
}

// InstallAddon unpacks and installs an addon package into the server and configures world bindings.
func (a *App) InstallAddon(serverID, archivePath string, opts addons.InstallOptions) (*addons.InstalledPackResult, error) {
	if a.supervisor.GetStatus() == models.StatusOnline || a.supervisor.GetStatus() == models.StatusStarting {
		return nil, fmt.Errorf("cannot install Add-Ons while server is running. Please stop the server first to protect world and pack files")
	}
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	return a.addonInstall.InstallAddon(s.Path, archivePath, opts)
}

// ListAddons enumerates all behavior and resource packs installed on the server.
func (a *App) ListAddons(serverID string) ([]models.Addon, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	return a.addonMgr.ListInstalledAddons(s.Path)
}

// AssignAddonToWorld activates a pack for a given world in its world_*_packs.json.
func (a *App) AssignAddonToWorld(serverID, worldName, packType, packUUID string, version []int) error {
	if a.supervisor.GetStatus() == models.StatusOnline || a.supervisor.GetStatus() == models.StatusStarting {
		return fmt.Errorf("cannot modify world pack bindings while server is running. Please stop the server first")
	}
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	return a.addonInstall.RegisterWorldPack(s.Path, worldName, packType, packUUID, version)
}

// UnassignAddonFromWorld removes a pack from a world's pack configuration list.
func (a *App) UnassignAddonFromWorld(serverID, worldName, packType, packUUID string) error {
	if a.supervisor.GetStatus() == models.StatusOnline || a.supervisor.GetStatus() == models.StatusStarting {
		return fmt.Errorf("cannot modify world pack bindings while server is running. Please stop the server first")
	}
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	return a.addonInstall.UnregisterWorldPack(s.Path, worldName, packType, packUUID)
}

// UninstallAddon deletes an addon pack from disk across both behavior and resource directories.
func (a *App) UninstallAddon(serverID, addonUUID string) error {
	if a.supervisor.GetStatus() == models.StatusOnline || a.supervisor.GetStatus() == models.StatusStarting {
		return fmt.Errorf("cannot delete add-ons while server is running. Please stop the server first")
	}
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	return a.addonMgr.UninstallAddon(s.Path, addonUUID)
}

// ExportAddon repackages an installed pack into an exportable .mcpack or .mcaddon archive.
func (a *App) ExportAddon(serverID, addonUUID string) (string, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return "", fmt.Errorf("server not found")
	}
	return a.addonMgr.ExportAddon(s.Path, addonUUID, "")
}

// ToggleAddonForWorld toggles whether an installed pack is active on a specific world.
func (a *App) ToggleAddonForWorld(serverID, worldName, addonUUID string, enable bool) error {
	if a.supervisor.GetStatus() == models.StatusOnline || a.supervisor.GetStatus() == models.StatusStarting {
		return fmt.Errorf("cannot modify world pack bindings while server is running. Please stop the server first")
	}
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	return a.addonMgr.ToggleAddonForWorld(s.Path, worldName, addonUUID, enable)
}

// ----------------- Worlds Management -----------------

// ListWorlds scans the worlds directory and returns all Bedrock level folders.
func (a *App) ListWorlds(serverID string) ([]models.World, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	return a.worldMgr.ListWorlds(s.Path)
}

// CreateWorld generates a new world directory with a default levelname.txt.
func (a *App) CreateWorld(serverID, folderName, displayName string) error {
	return a.CreateWorldWithOptions(serverID, models.WorldCreateOptions{
		FolderName:    folderName,
		DisplayName:   displayName,
		SetActive:     false,
		BehaviorPacks: []models.WorldPackRecord{},
		ResourcePacks: []models.WorldPackRecord{},
	})
}

// CreateWorldWithOptions provisions a new world with initial gamerules and pack configurations.
func (a *App) CreateWorldWithOptions(serverID string, opts models.WorldCreateOptions) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	if err := a.worldMgr.CreateWorldWithOptions(s.Path, opts); err != nil {
		return err
	}
	if opts.SetActive {
		_ = a.serverMgr.SetActiveWorld(serverID, opts.FolderName)
	}
	return nil
}

// SetActiveWorld updates server.properties to point level-name to the chosen world folder.
func (a *App) SetActiveWorld(serverID, worldFolder string) error {
	if err := a.serverMgr.SetActiveWorld(serverID, worldFolder); err != nil {
		return err
	}
	if s, ok := a.db.GetServer(serverID); ok {
		a.syncServerProperties(s)
	}
	return nil
}

// DeleteWorld removes a world directory from disk, preventing deletion of the active world.
func (a *App) DeleteWorld(serverID, worldFolder string) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	return a.worldMgr.DeleteWorld(s.Path, worldFolder, s.ActiveWorld)
}

// ----------------- Backups Management -----------------

// ListBackups enumerates all ZIP backup archives created for the server.
func (a *App) ListBackups(serverID string) ([]models.Backup, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	return a.backupMgr.ListBackups(s.ID, s.Name, s.Path)
}

// CreateBackup generates an instant or scheduled ZIP backup archive of worlds or entire server.
func (a *App) CreateBackup(serverID, backupType, worldName, description string) (*models.Backup, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	b, err := a.backupMgr.CreateBackup(s.ID, s.Name, s.Path, backupType, worldName, description)
	if err != nil {
		return nil, err
	}
	_ = a.db.SaveBackup(*b)

	retentionStr := a.db.GetPreference("backup_retention_count", "10")
	if maxCount, err := strconv.Atoi(retentionStr); err == nil && maxCount > 0 {
		_, _ = a.backupMgr.PruneOldBackups(s.Path, maxCount)
	}

	return b, nil
}

func (a *App) PruneBackups(serverID string, maxRetained int) (int, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return 0, fmt.Errorf("server not found")
	}
	return a.backupMgr.PruneOldBackups(s.Path, maxRetained)
}

func (a *App) RestoreBackup(serverID, backupFilePath string) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	return a.backupMgr.RestoreBackup(s.Path, backupFilePath)
}

func (a *App) GetPreference(key, defaultVal string) string {
	return a.db.GetPreference(key, defaultVal)
}

func (a *App) SetPreference(key, value string) error {
	return a.db.SetPreference(key, value)
}

// ----------------- Compatibility -----------------

func (a *App) CheckCompatibility(serverID string) (*compatibility.FullCompatibilityReport, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	modsList, _ := a.modMgr.ListMods(s.Path)
	addonsList, _ := a.addonMgr.ListInstalledAddons(s.Path)
	return a.compatEngine.CheckCompatibility(s.MinecraftVersion, s.LeviLaminaVersion, modsList, addonsList), nil
}

// ----------------- OS Native Dialogs -----------------

func (a *App) SelectFolderDialog() (string, error) {
	if a.ctx == nil {
		return "", fmt.Errorf("runtime context not ready")
	}
	return wailsruntime.OpenDirectoryDialog(a.ctx, wailsruntime.OpenDialogOptions{
		Title: "Select Folder",
	})
}

func (a *App) SelectFileDialog(title string, filterName string, pattern string) (string, error) {
	if a.ctx == nil {
		return "", fmt.Errorf("runtime context not ready")
	}
	return wailsruntime.OpenFileDialog(a.ctx, wailsruntime.OpenDialogOptions{
		Title: title,
		Filters: []wailsruntime.FileFilter{
			{
				DisplayName: filterName,
				Pattern:     pattern,
			},
		},
	})
}

// ----------------- Universal Import Center -----------------

type UniversalImportResult struct {
	Type        string                      `json:"type"` // "ADDON", "MOD", "WORLD", "BACKUP", "UNKNOWN"
	Success     bool                        `json:"success"`
	Name        string                      `json:"name,omitempty"`
	AddonResult *models.AddonAnalysisResult `json:"addonResult,omitempty"`
	Message     string                      `json:"message"`
}

func (a *App) InspectImportFile(filePath string) (*UniversalImportResult, error) {
	if _, err := os.Stat(filePath); err != nil {
		return nil, fmt.Errorf("file not found: %w", err)
	}

	ext := strings.ToLower(filepath.Ext(filePath))
	baseName := filepath.Base(filePath)

	// Check if addon (.mcaddon, .mcpack)
	if ext == ".mcaddon" || ext == ".mcpack" {
		analysis, err := a.addonAnalyzer.AnalyzeArchive(filePath)
		if err == nil && analysis.Valid {
			return &UniversalImportResult{
				Type:        "ADDON",
				Success:     true,
				Name:        analysis.Name,
				AddonResult: analysis,
				Message:     "Bedrock Add-On detected and analyzed successfully.",
			}, nil
		}
		return &UniversalImportResult{
			Type:    "ADDON",
			Success: true,
			Name:    baseName,
			Message: "Bedrock Add-On package detected.",
		}, nil
	}

	// Check if world template (.mctemplate)
	if ext == ".mctemplate" {
		if addonPath, err := a.extMgr.ConvertWorldTemplateToAddon(filePath); err == nil && addonPath != "" && addonPath != filePath {
			if analysis, err := a.addonAnalyzer.AnalyzeArchive(addonPath); err == nil && analysis.Valid {
				return &UniversalImportResult{
					Type:        "ADDON",
					Success:     true,
					Name:        analysis.Name,
					AddonResult: analysis,
					Message:     "Bedrock Add-On successfully extracted from World Template (Behavior Pack detected).",
				}, nil
			}
			return &UniversalImportResult{
				Type:    "ADDON",
				Success: true,
				Name:    filepath.Base(addonPath),
				Message: "Bedrock Add-On extracted from World Template.",
			}, nil
		}

		// If no behavior pack is present, it is a standalone World map/template -> treat as WORLD
		cleanWorldName := strings.TrimSuffix(baseName, ext)
		cleanWorldName = strings.ReplaceAll(cleanWorldName, " (world_template)", "")
		cleanWorldName = strings.TrimSpace(cleanWorldName)
		return &UniversalImportResult{
			Type:    "WORLD",
			Success: true,
			Name:    cleanWorldName,
			Message: "World Template map detected (no behavior pack). Ready to install as a new separate world.",
		}, nil
	}

	// Check if world (.mcworld)
	if ext == ".mcworld" {
		return &UniversalImportResult{
			Type:    "WORLD",
			Success: true,
			Name:    strings.TrimSuffix(baseName, ext),
			Message: "Minecraft World package (.mcworld) detected and ready to import.",
		}, nil
	}

	// Check if single mod plugin DLL (.dll)
	if ext == ".dll" {
		return &UniversalImportResult{
			Type:    "MOD",
			Success: true,
			Name:    baseName,
			Message: "LeviLamina native plugin binary (.dll) detected.",
		}, nil
	}

	// Check if zip archive (could be addon, world, mod, or backup)
	if ext == ".zip" {
		// First check if it's a valid addon archive
		if analysis, err := a.addonAnalyzer.AnalyzeArchive(filePath); err == nil && analysis.Valid {
			return &UniversalImportResult{
				Type:        "ADDON",
				Success:     true,
				Name:        analysis.Name,
				AddonResult: analysis,
				Message:     "Bedrock Add-On archive detected.",
			}, nil
		}

		// Inspect inner zip contents
		if zr, err := zip.OpenReader(filePath); err == nil {
			defer zr.Close()
			hasLevelDat := false
			hasTooth := false
			hasServerProps := false
			hasPluginDll := false

			for _, f := range zr.File {
				nameLower := strings.ToLower(f.Name)
				if strings.HasSuffix(nameLower, "level.dat") {
					hasLevelDat = true
				}
				if strings.HasSuffix(nameLower, "tooth.json") || strings.HasSuffix(nameLower, "lip.json") {
					hasTooth = true
				}
				if strings.HasSuffix(nameLower, "server.properties") {
					hasServerProps = true
				}
				if strings.HasSuffix(nameLower, ".dll") || strings.Contains(nameLower, "plugins/") {
					hasPluginDll = true
				}
			}

			if hasLevelDat {
				return &UniversalImportResult{
					Type:    "WORLD",
					Success: true,
					Name:    strings.TrimSuffix(baseName, ext),
					Message: "Minecraft Bedrock world archive (contains level.dat) detected.",
				}, nil
			}
			if hasTooth || hasPluginDll {
				return &UniversalImportResult{
					Type:    "MOD",
					Success: true,
					Name:    strings.TrimSuffix(baseName, ext),
					Message: "LeviLamina mod / plugin archive detected.",
				}, nil
			}
			if hasServerProps {
				return &UniversalImportResult{
					Type:    "BACKUP",
					Success: true,
					Name:    strings.TrimSuffix(baseName, ext),
					Message: "Full server backup archive detected.",
				}, nil
			}
		}
	}

	return &UniversalImportResult{
		Type:    "UNKNOWN",
		Success: false,
		Name:    baseName,
		Message: "File format inspected. Select target category to proceed.",
	}, nil
}

// ImportWorld extracts a .mcworld or zip archive into the worlds directory.
func (a *App) ImportWorld(serverID, archivePath string) (*models.World, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	return a.worldMgr.ImportWorldArchive(s.Path, archivePath)
}

// ----------------- Xbox Live & Microsoft Account -----------------

// GetXboxAccount returns cached Xbox Live profile credentials if available.
func (a *App) GetXboxAccount() (*models.XboxAccount, error) {
	return a.xboxMgr.GetSavedXboxAccount()
}

// DetectXboxAccount is a stub for local identity discovery.
func (a *App) DetectXboxAccount() (*models.XboxAccount, error) {
	return nil, fmt.Errorf("account auto-detection disabled")
}

// StartXboxDeviceAuth begins OAuth2 device code flow with Microsoft identity services.
func (a *App) StartXboxDeviceAuth() (*models.DeviceAuthResponse, error) {
	return a.xboxMgr.StartXboxDeviceAuth()
}

// PollXboxDeviceAuth polls Microsoft OAuth token endpoint until authorized.
func (a *App) PollXboxDeviceAuth(deviceCode string) (*models.XboxAccount, error) {
	return a.xboxMgr.PollXboxDeviceAuth(deviceCode)
}

// SaveXboxAccount stores Xbox Live account profile in local storage.
func (a *App) SaveXboxAccount(acc models.XboxAccount) error {
	return a.xboxMgr.SaveXboxAccount(acc)
}

// ClearXboxAccount purges active Xbox Live credentials.
func (a *App) ClearXboxAccount() error {
	return a.xboxMgr.ClearXboxAccount()
}

// AddXboxAccountAsOp adds the logged-in Xbox player as an operator in permissions.json.
func (a *App) AddXboxAccountAsOp(serverID string) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	acc, err := a.xboxMgr.GetSavedXboxAccount()
	if err != nil || !acc.IsLoggedIn {
		return fmt.Errorf("no active Xbox account logged in")
	}
	return a.xboxMgr.AddXboxAccountAsOp(s.Path, acc.Gamertag, acc.XUID)
}

// ----------------- Player Management -----------------

// GetPlayersOverview aggregates online players, operators, and allowlisted users.
func (a *App) GetPlayersOverview(serverID string) (*models.PlayersOverview, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	activePlayers := a.supervisor.GetActivePlayers()
	return a.playerMgr.GetOverview(s.Path, activePlayers)
}

// SetPlayerPermission updates player permissions in permissions.json and reloads in BDS.
func (a *App) SetPlayerPermission(serverID, xuid, permission string) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	err := a.playerMgr.SetOperator(s.Path, xuid, permission)
	if err == nil {
		_ = a.supervisor.SendCommand("permission reload")
	}
	return err
}

// AddAllowlistPlayer adds a gamertag/xuid to allowlist.json and syncs BDS runtime.
func (a *App) AddAllowlistPlayer(serverID, name, xuid string, ignoresLimit bool) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	err := a.playerMgr.AddAllowlistPlayer(s.Path, name, xuid, ignoresLimit)
	if err == nil {
		_ = a.supervisor.SendCommand(fmt.Sprintf("allowlist add %s", name))
		_ = a.supervisor.SendCommand("allowlist reload")
	}
	return err
}

// RemoveAllowlistPlayer removes a gamertag from allowlist.json and syncs BDS runtime.
func (a *App) RemoveAllowlistPlayer(serverID, target string) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	err := a.playerMgr.RemoveAllowlistPlayer(s.Path, target)
	if err == nil {
		_ = a.supervisor.SendCommand(fmt.Sprintf("allowlist remove %s", target))
		_ = a.supervisor.SendCommand("allowlist reload")
	}
	return err
}

// ToggleAllowlist updates white-list enforcement in server.properties.
func (a *App) ToggleAllowlist(serverID string, enabled bool) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	err := a.playerMgr.ToggleAllowlist(s.Path, enabled)
	if err == nil {
		if enabled {
			_ = a.supervisor.SendCommand("allowlist on")
		} else {
			_ = a.supervisor.SendCommand("allowlist off")
		}
	}
	return err
}

func (a *App) BanPlayer(serverID, name, xuid, reason string) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	err := a.playerMgr.BanPlayer(s.Path, name, xuid, reason, "Admin")
	if reason == "" {
		reason = "Banned by administrator"
	}
	_ = a.supervisor.SendCommand(fmt.Sprintf("kick %s %s", name, reason))
	return err
}

func (a *App) UnbanPlayer(serverID, target string) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	return a.playerMgr.UnbanPlayer(s.Path, target)
}

func (a *App) KickPlayer(name, reason string) error {
	if reason == "" {
		reason = "Kicked by administrator"
	}
	return a.supervisor.SendCommand(fmt.Sprintf("kick %s %s", name, reason))
}

func (a *App) OpPlayer(name, xuid string) error {
	if s := a.GetActiveServer(); s != nil {
		_ = a.playerMgr.SetOperator(s.Path, xuid, "operator")
	}
	return a.supervisor.SendCommand(fmt.Sprintf("op %s", name))
}

func (a *App) DeopPlayer(name, xuid string) error {
	if s := a.GetActiveServer(); s != nil {
		_ = a.playerMgr.SetOperator(s.Path, xuid, "member")
	}
	return a.supervisor.SendCommand(fmt.Sprintf("deop %s", name))
}

// ----------------- World Options -----------------

func (a *App) GetWorldOptions(serverID, worldFolder string) (*models.WorldOptions, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	return a.worldMgr.GetWorldOptions(s.Path, worldFolder)
}

func (a *App) SaveWorldOptions(serverID, worldFolder string, opts models.WorldOptions) error {
	if a.supervisor.GetStatus() == models.StatusOnline || a.supervisor.GetStatus() == models.StatusStarting {
		return fmt.Errorf("cannot rename world or modify world options while server is running. Please stop the server first")
	}
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	if err := a.worldMgr.SaveWorldOptions(s.Path, worldFolder, opts); err != nil {
		return err
	}
	// Always synchronize active world in server.properties and database
	targetName := worldFolder
	if strings.TrimSpace(opts.LevelName) != "" {
		targetName = strings.TrimSpace(opts.LevelName)
	}
	_ = a.serverMgr.SetActiveWorld(serverID, targetName)
	return nil
}

func (a *App) ReorderWorldPacks(serverID, worldFolder string, behaviorPacks, resourcePacks []models.WorldPackRecord) error {
	if a.supervisor.GetStatus() == models.StatusOnline || a.supervisor.GetStatus() == models.StatusStarting {
		return fmt.Errorf("cannot reorder world packs while server is running. Please stop the server first")
	}
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	return a.worldMgr.ReorderWorldPacks(s.Path, worldFolder, behaviorPacks, resourcePacks)
}

// ----------------- Memory Allocation Controls -----------------

func (a *App) SetServerMemoryLimit(serverID string, memoryMB int) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	if memoryMB <= 0 {
		memoryMB = 4096
	}
	props, err := server.LoadProperties(s.Path)
	if err != nil {
		return err
	}
	props.Set("max-memory-mb", fmt.Sprintf("%d", memoryMB))
	return props.Save()
}

func (a *App) GetServerMemoryLimit(serverID string) int {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return 4096
	}
	props, err := server.LoadProperties(s.Path)
	if err != nil {
		return 4096
	}
	return props.GetInt("max-memory-mb", 4096)
}

// ----------------- Data Purge & Factory Reset -----------------

// PurgeDownloadedCache deletes ~/.llsm cached tools, BDS files, and database
func (a *App) PurgeDownloadedCache() error {
	return a.WipeEverything(true)
}

// WipeEverything performs a complete nuclear wipe of all worlds, server instances, cache, and app data
func (a *App) WipeEverything(deleteServerFolders bool) error {
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = a.supervisor.Stop(ctx)

	// Terminate any lingering BDS or LIP processes to release Windows file locks
	_ = exec.Command("taskkill", "/F", "/IM", "bedrock_server.exe", "/T").Run()
	_ = exec.Command("taskkill", "/F", "/IM", "bedrock_server_mod.exe", "/T").Run()
	_ = exec.Command("taskkill", "/F", "/IM", "lip.exe", "/T").Run()
	time.Sleep(500 * time.Millisecond)

	// 1. Delete all server directories (including all worlds, packs, logs, BDS executables)
	if deleteServerFolders {
		servers := a.db.GetServers()
		for _, s := range servers {
			if s.Path != "" {
				cleanPath := filepath.Clean(s.Path)
				// Defensive safeguard against deleting system root
				if len(cleanPath) > 5 && !strings.EqualFold(cleanPath, "C:\\") && !strings.EqualFold(cleanPath, "C:\\Windows") && !strings.EqualFold(cleanPath, "C:\\Program Files") {
					_ = os.RemoveAll(cleanPath)
				}
			}
		}
	}

	// 2. Delete .llsm directory (~/.llsm)
	userHome, _ := os.UserHomeDir()
	if userHome != "" {
		_ = os.RemoveAll(filepath.Join(userHome, ".llsm"))
	}

	// 3. Delete AppData / LocalAppData WebView2 caches and local storage
	appData := os.Getenv("APPDATA")
	if appData != "" {
		_ = os.RemoveAll(filepath.Join(appData, "LeviLaminaServerManager.exe"))
		_ = os.RemoveAll(filepath.Join(appData, "levilamina-server-manager.exe"))
		_ = os.RemoveAll(filepath.Join(appData, "LeviLaminaServerManager"))
		_ = os.RemoveAll(filepath.Join(appData, "levilamina-server-manager"))
	}

	localAppData := os.Getenv("LOCALAPPDATA")
	if localAppData != "" {
		_ = os.RemoveAll(filepath.Join(localAppData, "LeviLaminaServerManager.exe"))
		_ = os.RemoveAll(filepath.Join(localAppData, "levilamina-server-manager.exe"))
		_ = os.RemoveAll(filepath.Join(localAppData, "LeviLaminaServerManager"))
		_ = os.RemoveAll(filepath.Join(localAppData, "levilamina-server-manager"))
	}

	return nil
}

// ----------------- Windows Platform Utilities -----------------

// EnableLoopbackExemption enables Minecraft Bedrock UWP client to connect to localhost / 127.0.0.1 on the same PC
func (a *App) EnableLoopbackExemption() (string, error) {
	cmd := exec.Command("CheckNetIsolation.exe", "LoopbackExempt", "-a", "-n=Microsoft.MinecraftUWP_8wekyb3d8bbwe")
	cmd.SysProcAttr = &syscall.SysProcAttr{
		HideWindow:    true,
		CreationFlags: 0x08000000, // CREATE_NO_WINDOW
	}
	out, err := cmd.CombinedOutput()
	if err != nil {
		return string(out), fmt.Errorf("failed to enable loopback: %w (%s)", err, string(out))
	}
	return "Loopback exemption enabled successfully! Minecraft Bedrock on this PC can now connect to 127.0.0.1", nil
}

// CheckVCRedist checks if the Microsoft Visual C++ 2015-2022 x64 Redistributable runtime is installed
func (a *App) CheckVCRedist() bool {
	sysDir := os.Getenv("SystemRoot")
	if sysDir == "" {
		sysDir = "C:\\Windows"
	}
	dllPath := filepath.Join(sysDir, "System32", "vcruntime140.dll")
	_, err := os.Stat(dllPath)
	return err == nil
}

// InstallVCRedist downloads and installs Microsoft Visual C++ 2015-2022 x64 Redistributable quietly
func (a *App) InstallVCRedist() error {
	url := "https://aka.ms/vs/17/release/vc_redist.x64.exe"
	resp, err := http.Get(url)
	if err != nil {
		return fmt.Errorf("failed to download VC++ redistributable: %w", err)
	}
	defer resp.Body.Close()

	tempFile := filepath.Join(os.TempDir(), "vc_redist.x64.exe")
	out, err := os.Create(tempFile)
	if err != nil {
		return err
	}
	defer out.Close()

	if _, err := io.Copy(out, resp.Body); err != nil {
		return err
	}

	cmd := exec.Command(tempFile, "/install", "/quiet", "/norestart")
	cmd.SysProcAttr = &syscall.SysProcAttr{
		HideWindow:    true,
		CreationFlags: 0x08000000, // CREATE_NO_WINDOW
	}
	return cmd.Run()
}

// GetAppSettings retrieves the saved application settings JSON from ~/.llsm/app_settings.json
func (a *App) GetAppSettings() (string, error) {
	home, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	settingsPath := filepath.Join(home, ".llsm", "app_settings.json")
	data, err := os.ReadFile(settingsPath)
	if err != nil {
		if os.IsNotExist(err) {
			return "", nil
		}
		return "", err
	}
	return string(data), nil
}

// SaveAppSettings saves the application settings JSON to ~/.llsm/app_settings.json
func (a *App) SaveAppSettings(settingsJson string) error {
	home, err := os.UserHomeDir()
	if err != nil {
		return err
	}
	llsmDir := filepath.Join(home, ".llsm")
	if err := os.MkdirAll(llsmDir, 0755); err != nil {
		return err
	}
	settingsPath := filepath.Join(llsmDir, "app_settings.json")
	return os.WriteFile(settingsPath, []byte(settingsJson), 0644)
}

// ----------------- Dynamic Updates Checker -----------------

// CheckAllUpdates checks updates for LeviLamina, BDS, LIP, and installed mods
func (a *App) CheckAllUpdates(serverID string) (*models.UpdateCheckReport, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 25*time.Second)
	defer cancel()
	return a.updateEngine.CheckAllUpdates(ctx, serverID)
}

// ApplyComponentUpdate executes an update for a specific component
func (a *App) ApplyComponentUpdate(serverID, compType, identifier, targetVersion string) (*lip.CommandResult, error) {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return nil, fmt.Errorf("server not found")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()
	return a.updateEngine.ApplyUpdate(ctx, s.Path, compType, identifier, targetVersion)
}

// SyncBedrinthCatalog forces a dynamic synchronization with Bedrinth repository index
func (a *App) SyncBedrinthCatalog() (int, error) {
	pkgs, err := a.bedrinthClient.ForceRefresh()
	if err != nil {
		return 0, err
	}
	return len(pkgs), nil
}

// CheckMarketplaceUpdates checks dynamic marketplace definitions, keys, and engine status
func (a *App) CheckMarketplaceUpdates() (*models.MarketplaceUpdateReport, error) {
	return a.extMgr.CheckMarketplaceUpdates()
}

// RefreshMarketplaceDefinitions dynamically reloads marketplace keys and PlayFab catalog
func (a *App) RefreshMarketplaceDefinitions() (*models.MarketplaceUpdateReport, error) {
	return a.extMgr.RefreshMarketplaceDefinitions()
}

// CheckCurseForgeUpdates checks dynamic CurseForge status
func (a *App) CheckCurseForgeUpdates() (*models.CurseForgeUpdateReport, error) {
	return a.extMgr.CheckCurseForgeUpdates()
}

// RefreshCurseForgeCatalog forces a dynamic refresh of the CurseForge catalog
func (a *App) RefreshCurseForgeCatalog() (*models.CurseForgeUpdateReport, error) {
	return a.extMgr.RefreshCurseForgeCatalog()
}

// -----------------------------------------------------------------------
// Extensions (ToolCoin & CurseForge)
// -----------------------------------------------------------------------

// GetExtensionsOverview returns status summary for ToolCoin, CurseForge, and addons.
func (a *App) GetExtensionsOverview(customToolCoinExe, customToolCoinDir string) (*models.ExtensionsOverview, error) {
	return a.extMgr.GetExtensionsOverview(customToolCoinExe, customToolCoinDir)
}

// LaunchToolCoin starts the external ToolCoin executable if configured.
func (a *App) LaunchToolCoin(customPath string) error {
	return a.extMgr.LaunchToolCoin(customPath)
}

// ListToolCoinDownloads enumerates packages discovered in the downloads folder.
func (a *App) ListToolCoinDownloads(customDir string) ([]models.ToolCoinPackage, error) {
	return a.extMgr.ListToolCoinDownloads(customDir)
}

// OpenToolCoinDownloadsFolder reveals the ToolCoin downloads directory in File Explorer.
func (a *App) OpenToolCoinDownloadsFolder(customDir string) error {
	dir := a.extMgr.GetToolCoinDownloadsDir(customDir)
	_ = os.MkdirAll(dir, 0755)
	return exec.Command("explorer.exe", dir).Start()
}

// InstallToolCoinPackage installs a downloaded .mcpack/.mcaddon from the downloads cache.
func (a *App) InstallToolCoinPackage(serverID, filePath string) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}
	return a.extMgr.InstallToolCoinPackage(s.Path, filePath)
}

// ScanRecentCurseForgeDownloads detects newly downloaded Bedrock mods from CurseForge.
func (a *App) ScanRecentCurseForgeDownloads() ([]models.CurseForgeDownloadItem, error) {
	return a.extMgr.ScanRecentCurseForgeDownloads()
}

// GetExtensionsCatalog returns available extension plugins and modules.
func (a *App) GetExtensionsCatalog() []models.ExtensionManifest {
	return a.extMgr.GetExtensionsCatalog()
}

// InstallExtension downloads and activates an internal manager extension.
func (a *App) InstallExtension(id string) error {
	return a.extMgr.InstallExtension(id)
}

// UninstallExtension removes an internal manager extension.
func (a *App) UninstallExtension(id string) error {
	return a.extMgr.UninstallExtension(id)
}

// SetExtensionEnabled activates or deactivates an installed extension.
func (a *App) SetExtensionEnabled(id string, enabled bool) error {
	return a.extMgr.SetExtensionEnabled(id, enabled)
}

// GetToolCoinCatalog returns indexed Bedrock Marketplace items filtered by search and category.
func (a *App) GetToolCoinCatalog(query, category string) []models.ToolCoinCatalogItem {
	return a.extMgr.GetToolCoinCatalog(query, category)
}

// InstallToolCoinCatalogItem downloads and binds a catalog item directly to the active server.
func (a *App) InstallToolCoinCatalogItem(serverID, itemID string) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}

	if a.activityLogger != nil {
		a.activityLogger.Log("MARKETPLACE", "Installing marketplace pack '%s' to server '%s'...", itemID, s.Name)
	}

	targetPath, err := a.extMgr.ResolveToolCoinItemPath(itemID)
	if err != nil {
		return err
	}

	ext := strings.ToLower(filepath.Ext(targetPath))
	if ext == ".mctemplate" || ext == ".mcworld" {
		err := a.extMgr.InstallToolCoinPackage(s.Path, targetPath)
		if err == nil && a.activityLogger != nil {
			a.activityLogger.Log("MARKETPLACE", "Successfully installed '%s' to server '%s'.", filepath.Base(targetPath), s.Name)
		}
		return err
	}

	targetWorld := addons.ResolveWorldFolder(s.Path, "")
	opts := addons.InstallOptions{
		EnableBehavior: true,
		EnableResource: true,
		TargetWorld:    targetWorld,
		CreateBackup:   false,
	}

	_, err = a.addonInstall.InstallAddon(s.Path, targetPath, opts)
	if err != nil {
		fallbackErr := a.extMgr.InstallToolCoinPackage(s.Path, targetPath)
		if fallbackErr == nil && a.activityLogger != nil {
			a.activityLogger.Log("MARKETPLACE", "Successfully installed '%s' to server '%s'.", filepath.Base(targetPath), s.Name)
		}
		return fallbackErr
	}

	if a.activityLogger != nil {
		a.activityLogger.Log("MARKETPLACE", "Successfully installed '%s' to server '%s'.", filepath.Base(targetPath), s.Name)
	}
	return nil
}

// DownloadMarketplaceItem fetches a Bedrock marketplace package directly into the local cache.
func (a *App) DownloadMarketplaceItem(itemID string) (string, error) {
	meta := a.extMgr.GetCatalog().Resolve(itemID, itemID, "")
	query := meta.Title
	if query == "" || strings.HasPrefix(query, "Marketplace Pack ") {
		query = itemID
	}
	if a.activityLogger != nil {
		a.activityLogger.Log("MARKETPLACE", "Downloading marketplace pack '%s'...", query)
	}
	res, err := a.extMgr.DownloadViaRustcoin(query, nil)
	if err == nil && a.activityLogger != nil {
		a.activityLogger.Log("MARKETPLACE", "Successfully downloaded '%s' (%s).", query, filepath.Base(res))
	}
	return res, err
}

// GetCurseForgeCatalog searches and retrieves community packs from CurseForge.
func (a *App) GetCurseForgeCatalog(query, category string) []models.CurseForgeCatalogItem {
	return a.extMgr.GetCurseForgeCatalog(query, category)
}

func (a *App) InstallCurseForgeCatalogItem(serverID, itemID, downloadURL, fileName string) error {
	return a.InstallCurseForgeItemLive(serverID, 0, 0, downloadURL, fileName)
}

func (a *App) GetToolCoinCatalogLive(query, category string, page, pageSize int) (*models.ToolCoinCatalogResponse, error) {
	return a.extMgr.GetToolCoinCatalogLive(query, category, page, pageSize)
}

func (a *App) GetCurseForgeCatalogLive(query, category string, sortField, page, pageSize int) (*models.CurseForgeCatalogResponse, error) {
	return a.extMgr.GetCurseForgeCatalogLive(query, category, sortField, page, pageSize)
}

func (a *App) InstallCurseForgeItemLive(serverID string, modID, fileID int, downloadURL, fileName string) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}

	tempFile, err := a.extMgr.DownloadCurseForgeItem(modID, fileID, downloadURL, fileName)
	if err != nil {
		return err
	}
	defer os.Remove(tempFile)

	targetWorld := addons.ResolveWorldFolder(s.Path, "")
	opts := addons.InstallOptions{
		EnableBehavior: true,
		EnableResource: true,
		TargetWorld:    targetWorld,
		CreateBackup:   false,
	}

	_, err = a.addonInstall.InstallAddon(s.Path, tempFile, opts)
	if err != nil {
		// Fallback to extMgr unpacker if AddonInstaller encountered non-standard structure (e.g. world template)
		fallbackErr := a.extMgr.InstallToolCoinPackage(s.Path, tempFile)
		if fallbackErr == nil {
			return nil
		}
		return err
	}
	if a.activityLogger != nil {
		a.activityLogger.Log("MARKETPLACE", "Successfully installed '%s' to server '%s'.", filepath.Base(tempFile), s.Name)
	}
	return nil
}

// GetMCPEDLCatalogLive retrieves live community addon listings from MCPEDL.
func (a *App) GetMCPEDLCatalogLive(query, category, sort string, page, pageSize int) (*models.MCPEDLCatalogResponse, error) {
	return a.extMgr.GetMCPEDLCatalogLive(query, category, sort, page, pageSize)
}

// SyncMCPEDLCatalog clears cached MCPEDL pages and loads fresh upstream listings.
func (a *App) SyncMCPEDLCatalog() (*models.MCPEDLCatalogResponse, error) {
	return a.extMgr.SyncMCPEDLCatalog()
}

// GetMCPEDLItemFiles fetches all available download files for an MCPEDL addon.
func (a *App) GetMCPEDLItemFiles(slug string) ([]models.MCPEDLDownloadFile, error) {
	return a.extMgr.GetMCPEDLItemFiles(slug)
}

// InstallMCPEDLItemLive downloads and installs a pack directly from MCPEDL into the server.
func (a *App) InstallMCPEDLItemLive(serverID, slug, downloadURL, fileName string) error {
	s, ok := a.db.GetServer(serverID)
	if !ok {
		return fmt.Errorf("server not found")
	}

	if a.activityLogger != nil {
		a.activityLogger.Log("MCPEDL", "Installing MCPEDL addon '%s' to server '%s'...", slug, s.Name)
	}

	if downloadURL == "" {
		files, err := a.extMgr.GetMCPEDLItemFiles(slug)
		if err != nil || len(files) == 0 {
			return fmt.Errorf("no download files found for %s", slug)
		}
		downloadURL = files[0].DownloadURL
		if fileName == "" {
			fileName = files[0].FileName
		}
	}

	tempFile, err := a.extMgr.DownloadMCPEDLItem(downloadURL, fileName)
	if err != nil {
		return err
	}
	defer os.Remove(tempFile)

	targetWorld := addons.ResolveWorldFolder(s.Path, "")
	opts := addons.InstallOptions{
		EnableBehavior: true,
		EnableResource: true,
		TargetWorld:    targetWorld,
		CreateBackup:   false,
	}

	_, err = a.addonInstall.InstallAddon(s.Path, tempFile, opts)
	if err != nil {
		fallbackErr := a.extMgr.InstallToolCoinPackage(s.Path, tempFile)
		if fallbackErr == nil {
			if a.activityLogger != nil {
				a.activityLogger.Log("MCPEDL", "Successfully installed '%s' to server '%s'.", filepath.Base(tempFile), s.Name)
			}
			return nil
		}
		return err
	}

	if a.activityLogger != nil {
		a.activityLogger.Log("MCPEDL", "Successfully installed '%s' to server '%s'.", filepath.Base(tempFile), s.Name)
	}
	return nil
}
