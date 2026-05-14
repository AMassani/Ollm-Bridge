param(
    [string]$OllamaServerURL = "http://localhost:11434",
    [string]$PublicModelsDir = "$env:USERPROFILE\publicmodels"
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Ollm Bridge Remote v1.0" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Testing connection to Ollama server at: $OllamaServerURL" -ForegroundColor Cyan

try {
    $response = Invoke-RestMethod -Uri "$OllamaServerURL/api/tags" -Method Get -TimeoutSec 5
    Write-Host "Connected to Ollama server successfully" -ForegroundColor Green
}
catch {
    Write-Host "ERROR: Cannot connect to Ollama server at $OllamaServerURL" -ForegroundColor Red
    Write-Host "Ensure the Ollama server is running and accessible." -ForegroundColor Red
    Write-Host "Usage: .\Ollm_Bridge_Remote_v1.0.ps1 -OllamaServerURL http://your-server:11434" -ForegroundColor Yellow
    exit 1
}

if (-not (Test-Path $PublicModelsDir)) {
    Write-Host "Creating Public Models Directory..." -ForegroundColor Cyan
    New-Item -Type Directory -Path $PublicModelsDir | Out-Null
    Write-Host "Public Models Directory created" -ForegroundColor Green
}
else {
    Write-Host "Public Models Directory confirmed" -ForegroundColor Green
}

if (Test-Path "$PublicModelsDir\lmstudio") {
    Write-Host "Resetting LM Studio directory..." -ForegroundColor Cyan
    Remove-Item -Path "$PublicModelsDir\lmstudio" -Recurse -Force
    Write-Host "LM Studio Directory Reset" -ForegroundColor Green
}

Write-Host "Creating lmstudio directory structure..." -ForegroundColor Cyan
New-Item -Type Directory -Path "$PublicModelsDir\lmstudio" | Out-Null
Write-Host "LM Studio Directory Created" -ForegroundColor Green

Write-Host ""
Write-Host "Fetching available models from remote server..." -ForegroundColor Cyan
Write-Host ""

$models = $response.models
$totalModels = $models.Count

if ($totalModels -eq 0) {
    Write-Host "No models found on remote Ollama server" -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $totalModels model(s) on remote server" -ForegroundColor Green
Write-Host ""

$modelCount = 0
foreach ($model in $models) {
    $modelCount = $modelCount + 1
    $modelName = $model.name
    $modelSize = $model.size
    $modelDigest = $model.digest
    
    $nameParts = $modelName -split ":"
    $baseName = $nameParts[0]
    if ($nameParts.Count -gt 1) {
        $tag = $nameParts[1]
    }
    else {
        $tag = "latest"
    }
    
    $sizeMB = [math]::Round($modelSize / 1MB, 2)
    $sizeGB = [math]::Round($modelSize / 1GB, 2)
    if ($sizeGB -ge 1) {
        $displaySize = "$sizeGB GB"
    }
    else {
        $displaySize = "$sizeMB MB"
    }
    
    Write-Host "[$modelCount/$totalModels] Processing: $modelName ($displaySize)" -ForegroundColor Magenta
    
    $modelDir = "$PublicModelsDir\lmstudio\$baseName"
    if (-not (Test-Path $modelDir)) {
        New-Item -Type Directory -Path $modelDir | Out-Null
    }
    
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
    Write-Host "  Created metadata for $modelName" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Ollm Bridge Remote Setup Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

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
        "2. Go to Settings - Local Server",
        "3. Under Connect to a Remote Server, enter: $OllamaServerURL",
        "4. Click Connect",
        "",
        "Option 2: Proxy Through Local Ollama",
        "1. Install Ollama on your Windows machine",
        "2. Start local Ollama: ollama serve",
        "3. Pull models from remote server into local Ollama",
        "4. Use LM Studio normally with local Ollama"
    )
} | ConvertTo-Json -Depth 10

Set-Content -Path $configPath -Value $config -Encoding UTF8

Write-Host "Configuration saved to: $configPath" -ForegroundColor Cyan
Write-Host ""
Write-Host "NEXT STEPS:" -ForegroundColor Yellow
Write-Host "1. Verify Ollama server is accessible at: $OllamaServerURL" -ForegroundColor Yellow
Write-Host "2. Open LM Studio" -ForegroundColor Yellow
Write-Host "3. Go to Settings - Local Server" -ForegroundColor Yellow
Write-Host "4. Select 'Connect to a Remote Server'" -ForegroundColor Yellow
Write-Host "5. Enter server URL: $OllamaServerURL" -ForegroundColor Yellow
Write-Host "6. Click Connect" -ForegroundColor Yellow
Write-Host ""
Write-Host "Models location: $PublicModelsDir\lmstudio" -ForegroundColor Green
Write-Host ""
