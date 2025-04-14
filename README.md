# Certificate Expiry Exporter for Prometheus

This repository contains a robust PowerShell script to export certificate expiry dates from Windows certificate stores and certificate files as Prometheus-compatible metrics.

## Features
- **Scans Windows Certificate Stores**: LocalMachine and CurrentUser stores (My, Root, CA by default).
- **Scans Certificate Files**: Supports PEM, DER, CRT, CER, PFX, P12 files in user-specified directories. Also supports Java Keystore (`.jks`) files if Java `keytool` is available.
- **Prometheus-Compatible Output**: Metrics are saved as a `.prom` file for easy scraping.
- **Dynamic Labels**: Metric labels adapt to available certificate properties (store, file, subject, issuer, etc). Labels are sanitized for Prometheus compatibility (no newlines, tabs, or unescaped quotes).
- **Configurable**: All variables (output dir, cert dirs, stores) are at the top of the script for easy adjustment.

## Usage

1. **Edit Variables**
   - Open `cert-exporter.ps1` in a text editor.
   - Adjust the following variables at the top of the script as needed:
     - `$OutputDir`: Directory where the `.prom` file will be saved.
     - `$OutputFile`: Name of the output file.
     - `$CertDirs`: Array of directories to scan for certificate files.
     - `$StoresToCheck`: List of Windows certificate stores to scan.

#### About `$StoresToCheck`

`$StoresToCheck` is an array that specifies which Windows certificate stores will be scanned by the script. Each entry is a hashtable with the following keys:

- **Location**: The context of the certificate store. Common values:
  - `LocalMachine`: System-wide stores (certificates available to all users)
  - `CurrentUser`: User-specific stores (certificates available only to the current user)
- **Name**: The logical name of the certificate store. Common values:
  - `My`: Personal certificates
  - `Root`: Trusted Root Certification Authorities
  - `CA`: Intermediate Certification Authorities

**Example:**
```powershell
$StoresToCheck = @(
    @{ Location = "LocalMachine"; Name = "My" },
    @{ Location = "LocalMachine"; Name = "Root" },
    @{ Location = "LocalMachine"; Name = "CA" },
    @{ Location = "CurrentUser";  Name = "My" },
    @{ Location = "CurrentUser";  Name = "Root" },
    @{ Location = "CurrentUser";  Name = "CA" }
)
```

You can add or remove entries to control which stores are included. For a full list of possible store names, see the [Microsoft documentation on StoreName](https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.x509certificates.storename).

---

#### Tip: Scanning Only Folders (No Certificate Stores)

If you want to scan only certificate files in folders (and skip all Windows certificate stores), set `$StoresToCheck` to an empty array at the top of your script:

```powershell
$StoresToCheck = @()  # Do not scan any Windows certificate stores
$CertDirs = @("C:\certs", "D:\more_certs")  # Directories to scan for certificate files
```

With this configuration, the script will only process certificate files found in the specified folders.


2. **Run the Script**
   - Open PowerShell with appropriate permissions.
   - Run the script:
     ```powershell
     .\cert-exporter.ps1
     ```
   - The metrics file will be saved in `$OutputDir` with the name `$OutputFile` (e.g., `C:\cert_metrics\cert_expiry_metrics.prom`).

3. **Prometheus Scraping**
   - Configure your Prometheus node exporter or file_sd to scrape the generated `.prom` file.

## Metric Format

Each certificate produces a metric line like:

```
windows_certificate_expiry_timestamp{store_location="LocalMachine",store_name="My",subject="CN=example",issuer="CN=CA",thumbprint="...",serial="...",expiry_human="4/14/2025 23:32:31"} 1744673551
```

- The value is the expiry date as a Unix timestamp.
- The `expiry_human` label contains the human-readable expiry date.
- Labels adapt to available certificate properties.
- If a certificate is loaded from a file containing a private key (PEM), the label `has_private_key="true"` is added.
- If a certificate is loaded from a Java Keystore (`.jks`), the label `from_jks="true"` is added.
- All label values are sanitized (no newlines, tabs, or unescaped quotes; long values are truncated).

## Requirements
- PowerShell 5.1 or later (Windows)
- Permissions to read certificate stores and files
- For `.jks` (Java Keystore) support: Java `keytool` must be available in your `PATH` and the keystore password should be provided in the `JKS_STOREPASS` environment variable (defaults to `changeit` if unset).

## Troubleshooting
- Ensure you have permissions to access all specified certificate stores and directories.
- If you encounter errors with specific certificate files, check file format and permissions.

## License
MIT
