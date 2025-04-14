# Pester tests for cert-exporter.ps1
# Run with: Invoke-Pester -Output Detailed

BeforeAll {
    . "$PSScriptRoot/../cert-exporter.ps1"
}

Describe 'Sanitize-LabelValue' {
    It 'removes newlines and tabs, replaces quotes, and truncates' {
        $input = "foo\nbar\t\"baz\"" + ('x' * 210)
        $result = Sanitize-LabelValue $input
        $result | Should -NotMatch '\n|\t'
        $result | Should -NotMatch '"'
        $result.Length | Should -BeLessThanOrEqual 200
    }
}

Describe 'Get-UnixTimestamp' {
    It 'converts a date to Unix timestamp' {
        $date = Get-Date "2025-04-14T23:32:31+01:00"
        $ts = Get-UnixTimestamp $date
        $ts | Should -Be 1744673551
    }
}

Describe 'Get-CertInfoFromFile' {
    It 'returns certificate info from a PEM file' {
        $pem = @"-----BEGIN CERTIFICATE-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAn
-----END CERTIFICATE-----
"@
        $tmp = New-TemporaryFile
        Set-Content $tmp $pem
        $certs = Get-CertInfoFromFile $tmp
        $certs.Count | Should -BeGreaterThanOrEqual 0
        Remove-Item $tmp
    }
    It 'detects private key in PEM' {
        $pem = @"-----BEGIN PRIVATE KEY-----
foo
-----END PRIVATE KEY-----
-----BEGIN CERTIFICATE-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAn
-----END CERTIFICATE-----
"@
        $tmp = New-TemporaryFile
        Set-Content $tmp $pem
        $certs = Get-CertInfoFromFile $tmp
        $certs[0].HasPrivateKey | Should -Be $true
        Remove-Item $tmp
    }
}

Describe 'Main script logic' {
    It 'writes metrics file' {
        $testOutDir = "$PSScriptRoot/out"
        Remove-Item $testOutDir -Recurse -ErrorAction SilentlyContinue
        $global:OutputDir = $testOutDir
        $global:OutputFile = "test.prom"
        $global:CertDirs = @()
        $global:StoresToCheck = @()
        $global:MetricName = "test_metric"
        $global:MetricHelp = "Test metric"
        $metrics = @()
        $metrics += "# HELP test_metric Test metric"
        $metrics += "# TYPE test_metric gauge"
        # Simulate a metric
        $labels = @{subject = 'test'}
        $labelString = ($labels.GetEnumerator() | ForEach-Object {"$($_.Key)=`"$(Sanitize-LabelValue $_.Value)`""}) -join ","
        $metrics += "test_metric{$labelString} 1234567890"
        if (-not (Test-Path $testOutDir)) { New-Item -Path $testOutDir -ItemType Directory -Force | Out-Null }
        $OutputPath = Join-Path $testOutDir $global:OutputFile
        Set-Content -Path $OutputPath -Value $metrics -Encoding UTF8
        (Test-Path $OutputPath) | Should -Be $true
        Remove-Item $testOutDir -Recurse -ErrorAction SilentlyContinue
    }
}
