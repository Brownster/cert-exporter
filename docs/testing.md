# Testing and CI for Certificate Expiry Exporter

This project uses [Pester](https://pester.dev/) for automated testing of the PowerShell code. Tests are located in the `tests/` directory and are run automatically via GitHub Actions CI.

## Test Coverage
- The test suite aims for **80% or higher code coverage** on `cert-exporter.ps1`.
- Coverage is enforced in CI: builds will fail if coverage drops below 80%.

## Running Tests Locally

1. **Install Pester** (if not already installed):
   ```powershell
   Install-Module -Name Pester -Force -SkipPublisherCheck
   ```

2. **Run all tests:**
   ```powershell
   Invoke-Pester -Output Detailed
   ```

3. **Run with code coverage:**
   ```powershell
   Invoke-Pester -Script tests/cert-exporter.Tests.ps1 -Output Detailed -CodeCoverage cert-exporter.ps1
   ```

## Test Structure
- **Sanitize-LabelValue**: Ensures label values are sanitized for Prometheus.
- **Get-UnixTimestamp**: Checks correct Unix timestamp conversion.
- **Get-CertInfoFromFile**: Validates PEM parsing and private key detection.
- **Main script logic**: Simulates metric file output.

## Continuous Integration (CI)
- The workflow is defined in `.github/workflows/pester.yml`.
- On each push or pull request, GitHub Actions:
  - Installs Pester
  - Runs all tests
  - Checks code coverage
  - Fails if coverage < 80%

## Adding More Tests
- Add new test files or cases in the `tests/` directory.
- Follow Pester's [documentation](https://pester.dev/docs/usage/writing-tests/) for best practices.

## Troubleshooting
- If a test fails, check the error message and confirm any environment dependencies (e.g., PowerShell version, file paths).
- For `.jks` support, ensure `keytool` and the correct environment variable are available.

---
For questions or help, open an issue or see the main [README.md](../README.md).
