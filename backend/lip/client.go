// Package lip provides a programmatic interface to LeviMC's official 'lip'
// package manager for LeviLamina mod and plugin distribution.
package lip

import (
	"archive/zip"
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"syscall"
	"time"
)

// LipClient encapsulates discovery, installation, and command dispatch for the 'lip' CLI.
type LipClient struct {
	customLipPath string
}

// NewLipClient creates an unconfigured LipClient instance.
func NewLipClient() *LipClient {
	return &LipClient{}
}

// CommandResult represents the structured standard I/O and exit status of a lip invocation.
type CommandResult struct {
	Success  bool   `json:"success"`
	ExitCode int    `json:"exitCode"`
	Stdout   string `json:"stdout"`
	Stderr   string `json:"stderr"`
	Error    string `json:"error,omitempty"`
}

// FindLipPath locates the lip binary via multi-tier discovery:
// 1. Explicitly configured path override
// 2. Active server instance directory (serverPath/lip.exe)
// 3. User toolchain directory (~/.llsm/tools/lip.exe)
// 4. System %PATH% environment variable
func (c *LipClient) FindLipPath(serverPath string) (string, bool) {
	if c.customLipPath != "" {
		if _, err := os.Stat(c.customLipPath); err == nil {
			return c.customLipPath, true
		}
	}

	// 1. Check in server root
	localServerLip := filepath.Join(serverPath, "lip.exe")
	if _, err := os.Stat(localServerLip); err == nil {
		return localServerLip, true
	}

	// 2. Check in app data / tools dir
	userHome, _ := os.UserHomeDir()
	appToolLip := filepath.Join(userHome, ".llsm", "tools", "lip.exe")
	if _, err := os.Stat(appToolLip); err == nil {
		return appToolLip, true
	}

	// 3. Check system PATH
	if p, err := exec.LookPath("lip.exe"); err == nil {
		if fi, err := os.Stat(p); err == nil && fi.Size() > 0 {
			return p, true
		}
	}
	if p, err := exec.LookPath("lip"); err == nil {
		if fi, err := os.Stat(p); err == nil && fi.Size() > 0 {
			return p, true
		}
	}

	// 4. Common standard Windows installation paths
	standardPaths := []string{
		`C:\Program Files\lip\lip.exe`,
		`C:\Program Files (x86)\lip\lip.exe`,
	}
	if localAppData := os.Getenv("LOCALAPPDATA"); localAppData != "" {
		standardPaths = append(standardPaths, filepath.Join(localAppData, "Programs", "lip", "lip.exe"))
	}
	for _, sp := range standardPaths {
		if fi, err := os.Stat(sp); err == nil && fi.Size() > 0 {
			return sp, true
		}
	}

	return "", false
}

// GetVersion returns LIP version string if available
func (c *LipClient) GetVersion(serverPath string) (string, error) {
	lipPath, found := c.FindLipPath(serverPath)
	if !found {
		return "", fmt.Errorf("lip binary not found")
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	cmd := exec.CommandContext(ctx, lipPath, "--version")
	cmd.SysProcAttr = &syscall.SysProcAttr{
		HideWindow:    true,
		CreationFlags: 0x08000000,
	}
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("failed to query lip version: %w", err)
	}

	return strings.TrimSpace(string(out)), nil
}

// RunLipCommand runs a lip command inside server directory
func (c *LipClient) RunLipCommand(ctx context.Context, serverPath string, args ...string) (*CommandResult, error) {
	lipPath, found := c.FindLipPath(serverPath)
	if !found {
		return nil, fmt.Errorf("lip is not installed. Please install LIP before running package operations")
	}

	cmd := exec.CommandContext(ctx, lipPath, args...)

	if serverPath != "" {
		cleanDir := filepath.Clean(serverPath)
		_ = os.MkdirAll(cleanDir, 0755)
		if info, err := os.Stat(cleanDir); err == nil && info.IsDir() {
			cmd.Dir = cleanDir
		}
	}
	cmd.SysProcAttr = &syscall.SysProcAttr{
		HideWindow:    true,
		CreationFlags: 0x08000000,
	}

	var stdoutBuf, stderrBuf bytes.Buffer
	cmd.Stdout = &stdoutBuf
	cmd.Stderr = &stderrBuf

	err := cmd.Run()
	res := &CommandResult{
		ExitCode: 0,
		Stdout:   stdoutBuf.String(),
		Stderr:   stderrBuf.String(),
	}

	if err != nil {
		res.Success = false
		if exitErr, ok := err.(*exec.ExitError); ok {
			res.ExitCode = exitErr.ExitCode()
		} else {
			res.ExitCode = -1
		}
		res.Error = err.Error()
	} else {
		res.Success = true
	}

	return res, nil
}

// InstallPackage runs `lip install <pkg>`
func (c *LipClient) InstallPackage(ctx context.Context, serverPath, pkgIdentifier string) (*CommandResult, error) {
	return c.RunLipCommand(ctx, serverPath, "install", pkgIdentifier, "-y")
}

// UpdatePackage runs `lip update <pkg>`
func (c *LipClient) UpdatePackage(ctx context.Context, serverPath, pkgIdentifier string) (*CommandResult, error) {
	return c.RunLipCommand(ctx, serverPath, "update", pkgIdentifier, "-y")
}

// InstallLipBinary downloads and extracts latest LIP release to user tools directory
func (c *LipClient) InstallLipBinary() (string, error) {
	userHome, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	toolsDir := filepath.Join(userHome, ".llsm", "tools")
	if err := os.MkdirAll(toolsDir, 0755); err != nil {
		return "", err
	}

	targetExe := filepath.Join(toolsDir, "lip.exe")

	// Fast Path 1: Check if targetExe already exists and is valid
	if fi, err := os.Stat(targetExe); err == nil && fi.Size() > 1000 {
		c.customLipPath = targetExe
		return targetExe, nil
	}

	// Fast Path 2: Check if lip is already available on the system
	if existing, found := c.FindLipPath(""); found && existing != targetExe {
		if err := copyLipFile(existing, targetExe); err == nil {
			c.customLipPath = targetExe
			return targetExe, nil
		}
		c.customLipPath = existing
		return existing, nil
	}

	// Determine download URLs: prioritize high-speed mirror and direct release asset
	candidateURLs := []string{
		"https://ghproxy.net/https://github.com/futrime/lip/releases/download/v0.34.8/lip-0.34.8-win-x64.zip",
		"https://github.com/futrime/lip/releases/download/v0.34.8/lip-0.34.8-win-x64.zip",
	}

	// Quick check for newer release URL with 2-second timeout
	if latestURL := resolveLipDownloadURL(); latestURL != "" && latestURL != candidateURLs[1] {
		candidateURLs = append([]string{latestURL}, candidateURLs...)
	}

	client := &http.Client{Timeout: 15 * time.Second}
	var lastErr error
	var body []byte

	for _, downloadURL := range candidateURLs {
		if downloadURL == "" {
			continue
		}
		req, err := http.NewRequest("GET", downloadURL, nil)
		if err != nil {
			continue
		}
		req.Header.Set("User-Agent", "LeviLaminaServerManager/1.0")

		resp, err := client.Do(req)
		if err != nil {
			lastErr = err
			continue
		}

		if resp.StatusCode != http.StatusOK {
			lastErr = fmt.Errorf("HTTP error %d downloading from %s", resp.StatusCode, downloadURL)
			resp.Body.Close()
			continue
		}

		body, err = io.ReadAll(resp.Body)
		resp.Body.Close()
		if err != nil {
			lastErr = err
			continue
		}

		if len(body) > 1000 {
			lastErr = nil
			break
		}
	}

	if lastErr != nil || len(body) == 0 {
		return "", fmt.Errorf("failed to download lip binary from all sources: %v", lastErr)
	}

	zr, err := zip.NewReader(bytes.NewReader(body), int64(len(body)))
	if err != nil {
		return "", fmt.Errorf("invalid lip zip archive: %w", err)
	}

	for _, f := range zr.File {
		if strings.EqualFold(filepath.Base(f.Name), "lip.exe") {
			rc, err := f.Open()
			if err != nil {
				return "", err
			}
			defer rc.Close()

			out, err := os.OpenFile(targetExe, os.O_CREATE|os.O_WRONLY|os.O_TRUNC, 0755)
			if err != nil {
				return "", err
			}
			defer out.Close()

			_, err = io.Copy(out, rc)
			if err != nil {
				return "", err
			}
			c.customLipPath = targetExe
			return targetExe, nil
		}
	}

	return "", fmt.Errorf("lip.exe not found inside downloaded release archive")
}

func copyLipFile(src, dst string) error {
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()

	if err := os.MkdirAll(filepath.Dir(dst), 0755); err != nil {
		return err
	}

	out, err := os.Create(dst)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, in)
	return err
}

func resolveLipDownloadURL() string {
	client := &http.Client{Timeout: 3 * time.Second}
	req, err := http.NewRequest("GET", "https://api.github.com/repos/LiteLDev/lip/releases/latest", nil)
	if err == nil {
		req.Header.Set("User-Agent", "LeviLaminaServerManager/1.0")
		resp, err := client.Do(req)
		if err == nil && resp.StatusCode == http.StatusOK {
			defer resp.Body.Close()
			var release struct {
				Assets []struct {
					Name               string `json:"name"`
					BrowserDownloadURL string `json:"browser_download_url"`
				} `json:"assets"`
			}
			if json.NewDecoder(resp.Body).Decode(&release) == nil {
				for _, a := range release.Assets {
					name := strings.ToLower(a.Name)
					if strings.Contains(name, "win") && strings.Contains(name, "x64") && strings.HasSuffix(name, ".zip") && !strings.Contains(name, "arm") {
						return a.BrowserDownloadURL
					}
				}
			}
		}
	}
	return "https://github.com/futrime/lip/releases/download/v0.34.8/lip-0.34.8-win-x64.zip"
}
