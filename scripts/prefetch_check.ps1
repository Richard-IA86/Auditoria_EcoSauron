# =============================================================
# prefetch_check.ps1
# Guardia de sincronizacion PREVIA a cualquier edicion.
# Equivalente Windows de prefetch_check.sh
#
# Uso:
#   .\scripts\prefetch_check.ps1 <repo_path>
#   .\scripts\prefetch_check.ps1 <repo_path> <archivo>
#
# Salida:
#   0 = seguro editar
#   1 = origin tiene commits nuevos -> hacer pull primero
#   2 = error de uso
# =============================================================
param(
    [string]$RepoPath = "",
    [string]$Archivo = ""
)

function Write-OK   { param([string]$Msg) Write-Host $Msg -ForegroundColor Green }
function Write-WARN { param([string]$Msg) Write-Host $Msg -ForegroundColor Yellow }
function Write-ERR  { param([string]$Msg) Write-Host $Msg -ForegroundColor Red }

if (-not $RepoPath) {
    Write-ERR "X Uso: .\scripts\prefetch_check.ps1 <repo_path> [archivo]"
    exit 2
}

$GitDir = Join-Path $RepoPath ".git"
if (-not (Test-Path $GitDir -PathType Container)) {
    Write-ERR "X No es un repo git: $RepoPath"
    exit 2
}

Push-Location $RepoPath
try {
    # --- Rama actual ------------------------------------------------
    $Rama = (git branch --show-current 2>&1) | Where-Object {
        $_ -is [string]
    } | Select-Object -First 1

    if (-not $Rama -or $Rama -match "^fatal:") {
        Write-WARN "? Repo en estado detached HEAD -- verificar manualmente."
        exit 1
    }

    # --- Fetch silencioso -------------------------------------------
    $null = git fetch --quiet origin 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-WARN (
            "? No se pudo conectar a origin" +
            " -- continuando sin verificacion remota."
        )
        exit 0
    }

    $Upstream = "origin/$Rama"

    # --- Verificar upstream remoto ----------------------------------
    $null = git rev-parse --verify $Upstream 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-OK "OK Rama '$Rama' sin upstream remoto -- seguro editar localmente."
        exit 0
    }

    # --- Contar commits divergentes ---------------------------------
    $AdelanteRaw = git rev-list "HEAD..$Upstream" --count 2>&1
    $Adelante = if ($AdelanteRaw -match '^\d+$') {
        [int]$AdelanteRaw.Trim()
    } else { 0 }

    $AtrasRaw = git rev-list "$Upstream..HEAD" --count 2>&1
    $Atras = if ($AtrasRaw -match '^\d+$') {
        [int]$AtrasRaw.Trim()
    } else { 0 }

    # --- Caso: origin adelantado ------------------------------------
    if ($Adelante -gt 0) {
        Write-ERR (
            "X DIVERGENCIA DETECTADA -- $Upstream tiene" +
            " $Adelante commit(s) que local NO tiene."
        )
        Write-Host ""
        Write-ERR "  Commits remotos pendientes de integrar:"
        git log --oneline "HEAD..$Upstream" |
            ForEach-Object { Write-Host "    $_" }
        Write-Host ""

        if ($Archivo) {
            # Normalizar separadores para comparar con git output
            $ArchivoRel = $Archivo
            if ($ArchivoRel.StartsWith($RepoPath)) {
                $ArchivoRel = $ArchivoRel.Substring($RepoPath.Length)
            }
            $ArchivoRel = $ArchivoRel.TrimStart('\').TrimStart('/') `
                -replace '\\', '/'

            $Modificados = git diff --name-only HEAD $Upstream 2>&1
            $Tocado = $Modificados | Where-Object { $_ -eq $ArchivoRel }

            if ($Tocado) {
                Write-ERR (
                    "  ! CONFLICTO POTENCIAL: '$ArchivoRel'" +
                    " fue modificado en origin."
                )
                Write-ERR "  Hacer git pull ANTES de editar ese archivo."
            } else {
                Write-WARN (
                    "  El archivo '$ArchivoRel' NO fue tocado en origin."
                )
                Write-WARN (
                    "  Igualmente se recomienda git pull antes de continuar."
                )
            }
        }

        Write-Host ""
        Write-WARN "  Accion requerida: git -C $RepoPath pull"
        exit 1
    }

    # --- Caso: local adelantado (sin push) --------------------------
    if ($Atras -gt 0) {
        Write-WARN (
            "? Local tiene $Atras commit(s) sin push" +
            " -- recordar publicar antes del cierre."
        )
    }

    # --- OK ---------------------------------------------------------
    if ($Archivo) {
        $ArchivoRel = $Archivo
        if ($ArchivoRel.StartsWith($RepoPath)) {
            $ArchivoRel = $ArchivoRel.Substring($RepoPath.Length)
        }
        $ArchivoRel = $ArchivoRel.TrimStart('\').TrimStart('/')
        Write-OK "OK Seguro editar '$ArchivoRel' -- sin divergencia en origin."
    } else {
        $Nombre = Split-Path $RepoPath -Leaf
        Write-OK "OK Repo '$Nombre' sincronizado -- seguro editar."
    }

    exit 0
}
finally {
    Pop-Location
}
