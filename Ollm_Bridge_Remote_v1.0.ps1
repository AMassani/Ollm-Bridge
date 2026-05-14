# Ollm Bridge Remote v1.0
# Bridges LM Studio with Ollama models hosted on a remote Linux server
# Uses Ollama API to pull model information without requiring local file access

param(
    [string]$OllamaServerURL = "http://localhost:11434",
    [string]$PublicModelsDir = "$env:USERPROFILE\publicmodels",
    [int]$DownloadParallel = 2
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Color output for better readability
function Write-Success { Write-Host $args -ForegroundColor Green }
function Write-Error-Custom { Write-Host $args -ForegroundColor Red }
function Write-Warning-Custom { Write-Host $args -ForegroundColor Yellow }
function Write-Info { Write-Host $args -ForegroundColor Cyan }

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Ollm Bridge Remote v1.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Validate Ollama server connection
Write-Info "Testing connection to Ollama server at: $OllamaServerURL"
try {
    $response = Invoke-RestMethod -Uri "$OllamaServerURL/api/tags" -Method Get -TimeoutSec 5
    Write-Success "✓ Connected to Ollama server successfully"
}
catch {
    Write-Error-Custom "✗ Cannot connect to Ollama server at $OllamaServerURL"
    Write-Host "Ensure the Ollama server is running and accessible."
    Write-Host "Usage: .\Ollm_Bridge_Remote_v1.0.ps1 -OllamaServerURL http://your-server:11434"
    exit 1
}

# Ensure public models directory exists
if (-not (Test-Path $PublicModelsDir)) {
    Write-Info "Creating Public Models Directory..."
    New-Item -Type Directory -Path $PublicModelsDir | Out-Null
    Write-Success "✓ Public Models Directory created"
}
else {
    Write-Success "✓ Public Models Directory confirmed"
}

# Reset lmstudio directory if it exists
if (Test-Path "$PublicModelsDir\lmstudio") {
    Write-Info "Resetting LM Studio directory..."
    Remove-Item -Path "$PublicModelsDir\lmstudio" -Recurse -Force
    Write-Success "✓ LM Studio Directory Reset"
}

# Create lmstudio directory
Write-Info "Creating lmstudio directory structure..."
New-Item -Type Directory -Path "$PublicModelsDir\lmstudio" | Out-Null
Write-Success "✓ LM Studio Directory Created"

Write-Host ""
Write-Info "Fetching available models from remote server..."
Write-Host ""

# Get list of available models from remote server
$models = $response.models
$totalModels = $models.Count

if ($totalModels -eq 0) {
    Write-Warning-Custom "No models found on remote Ollama server"
    exit 0
}

Write-Success "✓ Found $totalModels model(s) on remote server"
Write-Host ""

# Process each model
$modelCount = 0
foreach ($model in $models) {
    $modelCount++
    $modelName = $model.name
    $modelSize = $model.size
    $modelDigest = $model.digest
    
    # Extract model info from name (format: name:tag)
    $nameParts = $modelName -split ":"
    $baseName = $nameParts[0]
    $tag = if ($nameParts.Count -gt 1) { $nameParts[1] } else { "latest" }
    
    # Format size in human-readable format
    $sizeMB = [math]::Round($modelSize / 1MB, 2)
    $sizeGB = [math]::Round($modelSize / 1GB, 2)
    $displaySize = if ($sizeGB -ge 1) { "$sizeGB GB" } else { "$sizeMB MB" }
    
    Write-Host "[$modelCount/$totalModels] Processing: $modelName ($displaySize)" -ForegroundColor Magenta
    
    # Create model directory
    $modelDir = "$PublicModelsDir\lmstudio\$baseName"
    if (-not (Test-Path $modelDir)) {
        New-Item -Type Directory -Path $modelDir | Out-Null
    }
    
    # Create a model metadata file for LM Studio
    $metadataPath = "$modelDir\model.json"
    $metadata = @{
        name = $modelName
        displayName = $baseName
        tag = $tag
        size = $modelSize
        sizeFormatted = $displaySize
        digest = $modelDigest
        remoteServer = $OllamaServerURL
        bridgeVersion = "1.0"
        createdAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    } | ConvertTo-Json
    
    Set-Content -Path $metadataPath -Value $metadata -Encoding UTF8
    Write-Success "  ✓ Created metadata for $modelName"
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Success "✓ Ollm Bridge Remote Setup Complete!"
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Generate configuration file for LM Studio integration
$configPath = "$PublicModelsDir\lmstudio\ollm_remote_config.json"
$config = @{
    ollamaServer = $OllamaServerURL
    description = "Remote Ollama Bridge Configuration"
    setupDate = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    instructions = @(
        "LM Studio Connection Options:",
        "",
        "Option 1: Connect Directly to Remote Ollama Server",
        "1. Open LM Studio",
        "2. Go to Settings → Local Server",
        "3. Under 'Connect to a Remote Server', enter: $OllamaServerURL",
        "4. Click 'Connect'",
        "",
        "Option 2: Proxy Through Local Ollama (if available)",
        "1. Install Ollama on your Windows machine",
        "2. Start local Ollama: ollama serve",
        "3. Pull models from remote server into local Ollama",
        "4. Use LM Studio normally with local Ollama",
        "",
        "Option 3: Use Model Metadata Files",
        "Each model folder contains a model.json file with metadata.",
        "You can reference these for manual model configuration.",
        ""
    )
} | ConvertTo-Json -Depth 10

Set-Content -Path $configPath -Value $config -Encoding UTF8

Write-Info "Configuration saved to: $configPath"
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Verify the Ollama server is accessible at: $OllamaServerURL" -ForegroundColor Yellow
Write-Host "2. Open LM Studio and configure it to connect to your remote Ollama server" -ForegroundColor Yellow
Write-Host "3. Go to Settings → Local Server → Connect to Remote Server" -ForegroundColor Yellow
Write-Host "4. Enter the server URL: $OllamaServerURL" -ForegroundColor Yellow
Write-Host "5. You should now see all remote models available in LM Studio" -ForegroundColor Yellow
Write-Host ""
Write-Host "Troubleshooting:" -ForegroundColor Cyan
Write-Host "- If connection fails, check that your Linux server firewall allows port 11434" -ForegroundColor Cyan
Write-Host "- Ensure Ollama is running on the Linux server: 'ollama serve'" -ForegroundColor Cyan
Write-Host "- For network access, start Ollama with: 'OLLAMA_HOST=0.0.0.0:11434 ollama serve'" -ForegroundColor Cyan
Write-Host ""
Write-Host "Models location: $PublicModelsDir\lmstudio" -ForegroundColor Green
Write-Host ""
