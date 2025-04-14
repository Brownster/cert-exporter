# ==========================
# Certificate Expiry Exporter for Prometheus (Enhanced)
# ==========================
# ---- User Variables ----
$OutputDir = "C:\cert_metrics"   # Output directory for .prom file
$OutputFile = "cert_expiry_metrics.prom"   # Output .prom file name
$CertDirs = @("C:\certs", "D:\more_certs") # Directories to scan for individual certificate files
$StoresToCheck = @(
    @{ Location = "LocalMachine"; Name = "My" },
    @{ Location = "LocalMachine"; Name = "Root" },
    @{ Location = "LocalMachine"; Name = "CA" },
    @{ Location = "CurrentUser";  Name = "My" },
    @{ Location = "CurrentUser";  Name = "Root" },
    @{ Location = "CurrentUser";  Name = "CA" }
)
$MetricName = "windows_certificate_expiry_timestamp"
$MetricHelp = "Expiry date of certificates in Windows certificate stores and files as Unix timestamp"

# ---- Helper Functions ----
function Get-UnixTimestamp($date) {
    return [int][double]::Parse((Get-Date $date -UFormat %s))
}

function Sanitize-LabelValue($value) {
    $sanitized = $value -replace '"', "'"         # Replace double quotes
    $sanitized = $sanitized -replace '[\r\n\t]', ' ' # Remove newlines/tabs
    $sanitized = $sanitized.Trim()
    if ($sanitized.Length -gt 200) { $sanitized = $sanitized.Substring(0,200) } # Truncate if needed
    return $sanitized
}

function Get-CertInfoFromFile($filePath) {
    $certs = @()
    try {
        # Try to load as X509Certificate2Collection (supports PEM, DER, PFX)
        $collection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
        try { $collection.Import($filePath, $null, 'DefaultKeySet') } catch {}
        if ($collection.Count -eq 0) {
            # Try as PEM with multiple certs
            $pem = Get-Content $filePath -Raw
            $matches = [regex]::Matches($pem, "-----BEGIN CERTIFICATE-----(.*?)-----END CERTIFICATE-----", "Singleline")
            foreach ($match in $matches) {
                $bytes = [Convert]::FromBase64String($match.Groups[1].Value -replace '\s', '')
                $cert = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $bytes
                $collection.Add($cert)
            }
        }
        foreach ($cert in $collection) {
            $certs += [PSCustomObject]@{
                Subject    = $cert.Subject
                Issuer     = $cert.Issuer
                Thumbprint = $cert.Thumbprint
                Serial     = $cert.SerialNumber
                NotAfter   = $cert.NotAfter
                NotBefore  = $cert.NotBefore
                SourceFile = $filePath
            }
        }
    } catch {
        Write-Warning "Failed to load certificate from file $filePath: $_"
    }
    return $certs
}

# ---- Main Script ----
$metrics = @()
$metrics += "# HELP $MetricName $MetricHelp"
$metrics += "# TYPE $MetricName gauge"

# -- From Windows Cert Stores --
foreach ($store in $StoresToCheck) {
    $storeLocation = $store.Location
    $storeName = $store.Name

    try {
        $certStore = New-Object System.Security.Cryptography.X509Certificates.X509Store($storeName, $storeLocation)
        $certStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)

        foreach ($cert in $certStore.Certificates) {
            $labels = @{}
            $labels.store_location = $storeLocation
            $labels.store_name = $storeName
            if ($cert.Subject)    { $labels.subject = $cert.Subject }
            if ($cert.Issuer)     { $labels.issuer = $cert.Issuer }
            if ($cert.Thumbprint) { $labels.thumbprint = $cert.Thumbprint }
            if ($cert.SerialNumber) { $labels.serial = $cert.SerialNumber }
            if ($cert.NotAfter)   { $labels.expiry_human = $cert.NotAfter }
            $notAfterUnix = Get-UnixTimestamp $cert.NotAfter

            # Build label string dynamically
            $labelString = ($labels.GetEnumerator() | ForEach-Object { "$($_.Key)=`"$(Sanitize-LabelValue $_.Value)`"" }) -join ","
            $metrics += "$MetricName{$labelString} $notAfterUnix"
        }
        $certStore.Close()
    } catch {
        Write-Warning "Failed to open store $($storeLocation)\$($storeName): $_"
    }
}

# -- From Cert Files in Directories --
foreach ($dir in $CertDirs) {
    if (-not (Test-Path $dir)) { continue }
    $files = Get-ChildItem -Path $dir -File -Include *.cer,*.crt,*.pem,*.der,*.pfx,*.p12 -Recurse -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $certObjs = Get-CertInfoFromFile $file.FullName
        foreach ($cert in $certObjs) {
            $labels = @{}
            $labels.source_file = $file.FullName
            if ($cert.Subject)    { $labels.subject = $cert.Subject }
            if ($cert.Issuer)     { $labels.issuer = $cert.Issuer }
            if ($cert.Thumbprint) { $labels.thumbprint = $cert.Thumbprint }
            if ($cert.Serial)     { $labels.serial = $cert.Serial }
            if ($cert.NotAfter)   { $labels.expiry_human = $cert.NotAfter }
            if ($cert.PSObject.Properties.Match('HasPrivateKey') -and $cert.HasPrivateKey) { $labels.has_private_key = "true" }
            if ($cert.PSObject.Properties.Match('FromJKS') -and $cert.FromJKS) { $labels.from_jks = "true" }
            $notAfterUnix = Get-UnixTimestamp $cert.NotAfter

            $labelString = ($labels.GetEnumerator() | ForEach-Object { "$($_.Key)=`"$(Sanitize-LabelValue $_.Value)`"" }) -join ","
            $metrics += "$MetricName{$labelString} $notAfterUnix"
        }
    }
}

# ---- Output ----
if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
}
$OutputPath = Join-Path $OutputDir $OutputFile
Set-Content -Path $OutputPath -Value $metrics -Encoding UTF8

Write-Host "Metrics written to $OutputPath"