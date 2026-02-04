# EnvGuard Pro

**Environment variable validation with SARIF output and AWS integration**

This is the Pro version of [EnvGuard](https://github.com/szlaskidaniel/envguard), distributed via GitHub Packages.

## Proof of Identity & Code Transparency

This package is published and maintained by **Daniel Szlaski** ([GitHub](https://github.com/szlaskidaniel)).

**Why is the code obfuscated?**

EnvGuard Pro is distributed with obfuscated source code to protect intellectual property while still providing full functionality. This is a common practice for commercial software distributed via npm.

**What you can verify:**
- ✅ Published under the `@danielszlaski` npm scope (verified ownership)
- ✅ Built on the open-source [EnvGuard](https://github.com/szlaskidaniel/envguard) foundation
- ✅ No network calls except explicit AWS SDK operations (when `--aws` flag is used)
- ✅ No telemetry or data collection
- ✅ All CLI commands and behavior documented in this README

**Trust & Security:**
- The free version source code is fully available at [github.com/szlaskidaniel/envguard](https://github.com/szlaskidaniel/envguard)
- Pro features extend the open-source core without modifying its behavior
- Feel free to audit network traffic or sandbox the tool if needed

If you have security concerns, please open an issue or contact the maintainer directly.

## EnvGuard Free vs Pro

| Capability | EnvGuard Free | EnvGuard Pro |
|------------|---------------|--------------|
| Source code | Fully open source (MIT) | Distributed via npm with obfuscated sources for IP protection |
| Custom shell env files | Not supported – scans standard `.env` inputs only | Supports `envFiles` so you can import custom `.sh` scripts (for example `set-env.sh`) via config or `envguard-pro scan --env-files ...` |
| SARIF output | Not available | `--format sarif` to upload into GitHub Security |
| AWS validation | Not available | `--aws`, `--aws-deep`, and related flags validate SSM/Secrets before deploy |

Use the free version when you just need the baseline `.env` scanning workflow, and upgrade to Pro when you want advanced CI-ready outputs, AWS checks, or the ability to pull environment variables from reusable shell snippets maintained outside of `.env` files.

## Features

- **SARIF Output** - Integrate with GitHub Security tab for compliance tracking
- **AWS SSM Validation** - Verify environment variables exist in AWS Parameter Store
- All features from [EnvGuard Free](https://github.com/szlaskidaniel/envguard)


## Installation

For a dedicated, step-by-step install page (same layout as the site), see `installation.html`.

EnvGuard Pro is distributed as a `.tar.gz` package from a private GitHub repository. Follow the steps below to install it in your project.

### 1. Obtain the package

Download the `.tar.gz` archive from the private repository (you need appropriate access).

### 2. Place it in your project

Copy the archive into a `libs/` folder at the root of your project:

```
your-project/
├── libs/
│   └── danielszlaski-envguard-pro-1.0.0.tgz
├── src/
├── package.json
└── ...
```

### 3. Install via npm

Run the following command from your project root, pointing npm at the local archive:

```bash
npm install ./libs/danielszlaski-envguard-pro-1.0.0.tgz
```

npm will resolve the package from the local file and add it to `node_modules`. Once the command completes the package is ready to use — no additional configuration or registry setup is required.

## Usage

### Configuration

EnvGuard Pro uses `.envguardrc.json` (or `package.json`) for configuration. All options from the free version are supported, plus Pro-specific features.

**Example `.envguardrc.json`:**

```json
{
  "ignoreVars": ["MY_COMPANY_VAR", "PLATFORM_VAR"],
  "strict": false,
  "detectFallbacks": true,
  "exclude": ["**/build/**", "**/tmp/**"],
  "envFiles": ["set-env.sh", "another-env.sh"]
}
```

**Configuration options:**

- `ignoreVars` (string[]): Environment variables to ignore in non-strict mode
- `strict` (boolean): Enable strict mode by default (reports all variables including known runtime vars)
- `detectFallbacks` (boolean): Detect fallback patterns and treat them as warnings instead of errors (default: `true`)
- `exclude` (string[]): File patterns to exclude from scanning
- `envFiles` (string[]): Shell script env files to include (Pro feature)

**CLI flags override config:**
- Use `--strict` to enable strict mode regardless of config
- Use `--no-detect-fallbacks` to treat all missing variables as errors regardless of config

### Shell Script Environment Files (Pro Feature)

EnvGuard Pro can parse shell scripts (like `set-env.sh`) that define environment variables using `export` statements.

**Configuration in `.envguardrc.json`:**

```json
{
  "envFiles": ["set-env.sh", "another-env.sh"]
}
```

Or via CLI:

```bash
envguard-pro scan --env-files set-env.sh
```

### Fallback Detection

By default, EnvGuard detects when your code has fallback values for missing environment variables and treats them as warnings instead of errors.

**Example:**

```javascript
// These will be warnings (not errors) when MY_VAR is missing:
const value = process.env.MY_VAR || 'default';
const value = process.env.MY_VAR ?? 'default';
const value = process.env.MY_VAR ? process.env.MY_VAR : 'default';
```

**Disable fallback detection:**

Via config:
```json
{
  "detectFallbacks": false
}
```

Or via CLI:
```bash
envguard-pro scan --no-detect-fallbacks
```

**Why this matters:** Variables with defensive fallbacks are less critical than those that will cause `undefined` errors. This helps you prioritize fixes while staying aware of all env var usage.

### CI/CD Integration

Use the `--ci` flag to integrate EnvGuard Pro into your CI/CD pipelines. When enabled, the scan will exit with error code 1 if any errors are found, causing your pipeline to fail.

```bash
envguard-pro scan --ci
```

**What happens with `--ci`:**
- Exits with code 1 if any missing environment variables (errors) are found
- Exits with code 1 if any AWS resources are missing (when using `--aws`)
- Exits with code 0 if only warnings or info-level issues are found

**Combine with other flags for stricter checks:**

```bash
# Fail on any issue including warnings
envguard-pro scan --ci --strict

# Include AWS validation in CI checks
envguard-pro scan --ci --aws

# Treat all missing vars as errors (ignore fallbacks)
envguard-pro scan --ci --no-detect-fallbacks
```

### SARIF Output for GitHub Security

```bash
envguard-pro scan --format sarif --output results.sarif
```

### AWS Integration

EnvGuard Pro can validate that your environment variables exist in AWS SSM Parameter Store and Secrets Manager before deployment.

#### Basic AWS Validation

```bash
# Auto-detect SSM/Secrets references from serverless.yml
envguard-pro scan --aws

# Specify AWS region and profile
envguard-pro scan --aws --aws-region us-west-2 --aws-profile myprofile

# Fallback mode with prefix (when no serverless.yml)
envguard-pro scan --aws --aws-prefix "/myapp/prod/"
```

**Required IAM Permissions:**
- `ssm:GetParameter` - For SSM Parameter Store validation
- `secretsmanager:DescribeSecret` - For Secrets Manager validation

#### Deep Secret Validation (Nested Keys)

When your serverless.yml references nested keys within secrets:

```yaml
custom:
  secrets_AURORA: ${ssm:/aws/reference/secretsmanager/myapp/dev/aurora}

provider:
  environment:
    AURORA_HOST: ${self:custom.secrets_AURORA.host}
    AURORA_PORT: ${self:custom.secrets_AURORA.port}
```

Use `--aws-deep` to validate that nested keys (`host`, `port`) actually exist within the secret JSON:

```bash
envguard-pro scan --aws --aws-deep
```

**Additional IAM Permission Required:**
- `secretsmanager:GetSecretValue` - Required to fetch and parse the secret JSON

**Example Output:**

When all validations pass:
```
✔ All AWS resources validated successfully
  Secrets Manager (1):
    • myapp/dev/aurora
      └─ host ✔
      └─ port ✔
```

When nested keys are missing:
```
✖ Missing Secret Keys:
   • myapp/dev/aurora.username (used by AURORA_USERNAME)
```

#### AWS CLI Options

| Option | Description |
|--------|-------------|
| `--aws` | Enable AWS validation (auto-detects from serverless.yml) |
| `--aws-deep` | Also validate nested keys within secrets |
| `--aws-prefix <prefix>` | Prefix for fallback mode (e.g., `/myapp/prod/`) |
| `--aws-region <region>` | AWS region (defaults to `AWS_REGION` or serverless.yml) |
| `--aws-profile <profile>` | AWS profile (defaults to serverless.yml `provider.profile`) |
