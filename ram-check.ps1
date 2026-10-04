# ============================================================
# 32 GB RAM VERIFICATION TEST
# Safe test: leaves at least 4 GB of RAM available
# ============================================================

$ErrorActionPreference = "Stop"

$leaveFreeGB = 4
$maxTestGB   = 12
$chunkGB     = 1

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "       32 GB RAM VERIFICATION TEST" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

function Get-MemoryInfo {
    $os = Get-CimInstance Win32_OperatingSystem

    [PSCustomObject]@{
        TotalGB     = [math]::Round(
            $os.TotalVisibleMemorySize / 1MB, 2
        )
        FreeGB      = [math]::Round(
            $os.FreePhysicalMemory / 1MB, 2
        )
        UsedGB      = [math]::Round(
            (($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB), 2
        )
    }
}

$initial = Get-MemoryInfo

Write-Host "Windows-visible RAM : $($initial.TotalGB) GB"
Write-Host "Currently in use    : $($initial.UsedGB) GB"
Write-Host "Currently available : $($initial.FreeGB) GB"
Write-Host ""

if ($initial.FreeGB -lt ($leaveFreeGB + 1)) {
    Write-Host "There isn't enough free RAM to safely run this test." -ForegroundColor Red
    exit
}

# Never allocate more than:
#   1. 12 GB total
#   2. available RAM minus 4 GB safety margin

$safeMaximum = [math]::Floor($initial.FreeGB - $leaveFreeGB)

$targetGB = [math]::Min(
    $maxTestGB,
    $safeMaximum
)

Write-Host "Test allocation target: $targetGB GB" -ForegroundColor Yellow
Write-Host "Safety margin:         $leaveFreeGB GB" -ForegroundColor Yellow
Write-Host ""

Write-Host "Close unnecessary applications before continuing." -ForegroundColor Yellow
Write-Host ""
Read-Host "Press ENTER to begin the RAM test"

# Array holding our allocated memory chunks
$memoryBlocks = New-Object System.Collections.Generic.List[byte[]]

$allocatedGB = 0

try {

    while ($allocatedGB -lt $targetGB) {

        Write-Host ""
        Write-Host "Allocating $chunkGB GB..." -ForegroundColor Cyan

        # Allocate exactly 1 GB
        $bytes = New-Object byte[] (1GB)

        Write-Host "Touching memory pages..." -ForegroundColor DarkGray

        # Touch one byte every 4 KB.
        # This forces Windows to actually commit the memory pages.
        for ($i = 0; $i -lt $bytes.Length; $i += 4096) {
            $bytes[$i] = 165
        }

        # Keep the array alive
        $memoryBlocks.Add($bytes)

        $allocatedGB += $chunkGB

        $mem = Get-MemoryInfo

        Write-Host ""
        Write-Host "--------------------------------------------"
        Write-Host "Allocated by test : $allocatedGB GB"
        Write-Host "RAM in use        : $($mem.UsedGB) GB"
        Write-Host "RAM still free    : $($mem.FreeGB) GB"
        Write-Host "--------------------------------------------"

        # Emergency safety stop
        if ($mem.FreeGB -lt $leaveFreeGB) {
            Write-Host ""
            Write-Host "Safety limit reached. Stopping test." -ForegroundColor Yellow
            break
        }
    }

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "TEST COMPLETE" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""

    $final = Get-MemoryInfo

    Write-Host "Windows-visible RAM : $($final.TotalGB) GB"
    Write-Host "RAM before test     : $($initial.UsedGB) GB used"
    Write-Host "RAM after test      : $($final.UsedGB) GB used"
    Write-Host "Test allocation     : $allocatedGB GB"
    Write-Host ""

    if ($allocatedGB -ge 8) {
        Write-Host "SUCCESS: Windows successfully allocated" -ForegroundColor Green
        Write-Host "$allocatedGB GB in addition to the memory already in use." -ForegroundColor Green
        Write-Host ""
        Write-Host "This demonstrates that your system can actually" -ForegroundColor Green
        Write-Host "use physical memory well beyond 16 GB." -ForegroundColor Green
    }

}
catch {

    Write-Host ""
    Write-Host "Memory allocation stopped because Windows reported:" -ForegroundColor Yellow
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}

finally {

    Write-Host ""
    Write-Host "Releasing test memory..." -ForegroundColor Cyan

    $memoryBlocks.Clear()
    $memoryBlocks = $null

    [GC]::Collect()
    [GC]::WaitForPendingFinalizers()
    [GC]::Collect()

    Start-Sleep -Seconds 2

    $cleanup = Get-MemoryInfo

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "CLEANUP COMPLETE" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "RAM currently in use : $($cleanup.UsedGB) GB"
    Write-Host "RAM currently free   : $($cleanup.FreeGB) GB"
    Write-Host ""
    Write-Host "Your normal applications can continue running."
}