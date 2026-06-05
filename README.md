# JFrog Delete Old Builds

A bash script to delete old builds from JFrog Artifactory that match a naming pattern and are older than a specified number of days.

## Features

- ✅ Filter builds by regex pattern matching
- ✅ Delete builds older than a specified number of days
- ✅ Dry-run mode for safe testing
- ✅ Debug mode for troubleshooting
- ✅ Cross-platform support (macOS and Linux)
- ✅ Proper HTTP response code validation
- ✅ Robust JSON parsing with `jq`
- ✅ Comprehensive logging with color-coded output

## Requirements

- `bash` (4.0+)
- `curl`
- `jq`

### Installation

**macOS:**
```bash
brew install jq curl
```

**Ubuntu/Debian:**
```bash
sudo apt-get install jq curl
```

**CentOS/RHEL:**
```bash
sudo yum install jq curl
```

## Usage

### Basic Usage

```bash
JFROG_URL="https://artifactory.example.com" \
JFROG_USERNAME="admin" \
JFROG_API_KEY="your-api-key" \
BUILD_PATTERN="myapp-.*" \
./jfrog-delete-old-builds.sh
```

### Environment Variables

**Required:**
- `JFROG_URL` - JFrog Artifactory URL (e.g., `https://artifactory.example.com`)
- `JFROG_USERNAME` - JFrog username
- `JFROG_API_KEY` - JFrog API key or password
- `BUILD_PATTERN` - Regex pattern to match build names (e.g., `myapp-.*`)

**Optional:**
- `DAYS_OLD` - Delete builds older than this many days (default: `30`)
- `DRY_RUN` - Set to `true` to preview deletions without executing (default: `false`)
- `DEBUG` - Set to `true` for debug output (default: `false`)

### Examples

**Delete builds older than 30 days:**
```bash
JFROG_URL="https://artifactory.example.com" \
JFROG_USERNAME="admin" \
JFROG_API_KEY="your-api-key" \
BUILD_PATTERN="myapp-.*" \
./jfrog-delete-old-builds.sh
```

**Dry run to preview deletions:**
```bash
JFROG_URL="https://artifactory.example.com" \
JFROG_USERNAME="admin" \
JFROG_API_KEY="your-api-key" \
BUILD_PATTERN="myapp-.*" \
DRY_RUN="true" \
./jfrog-delete-old-builds.sh
```

**Delete builds older than 60 days:**
```bash
JFROG_URL="https://artifactory.example.com" \
JFROG_USERNAME="admin" \
JFROG_API_KEY="your-api-key" \
BUILD_PATTERN="test-.*" \
DAYS_OLD="60" \
./jfrog-delete-old-builds.sh
```

**Enable debug mode:**
```bash
JFROG_URL="https://artifactory.example.com" \
JFROG_USERNAME="admin" \
JFROG_API_KEY="your-api-key" \
BUILD_PATTERN="myapp-.*" \
DEBUG="true" \
./jfrog-delete-old-builds.sh
```

## API Details

The script uses the following JFrog Artifactory APIs:

### List All Builds
```
GET /api/builds
```
Returns a list of all builds with their names.

### Get Build Numbers
```
GET /api/build/{buildName}
```
Returns build numbers for a specific build name.

### Get Build Info
```
GET /api/build/{buildName}/{buildNumber}
```
Returns detailed information including the `started` timestamp.

### Delete Build
```
DELETE /api/build/{buildName}?buildNumbers={buildNumber}&deleteArtifacts=1
```
Deletes a specific build and its artifacts.

## Output

The script logs all operations to stderr with color-coded output:

- **[INFO]** - Informational messages (blue)
- **[SUCCESS]** - Successful operations (green)
- **[WARN]** - Warnings (yellow)
- **[ERROR]** - Error messages (red)
- **[DEBUG]** - Debug information (blue, only in DEBUG mode)

Example output:
```
[INFO] Starting JFrog build cleanup script
[INFO] Platform: macOS
[INFO] URL: https://artifactory.example.com
[INFO] Pattern: myapp-.*
[INFO] Days old threshold: 30
[INFO] Fetching builds from JFrog...
[INFO] Processing build: myapp-production-build
[INFO] Checking build: myapp-production-build/2024-01-15-123456
[INFO] Build age: 45 days (threshold: 30 days)
[WARN] [DRY RUN] Would delete: myapp-production-build/2024-01-15-123456
[INFO] Cleanup complete
[INFO] Deleted: 0 builds
[INFO] Skipped: 1 builds
```

## Error Handling

The script validates HTTP response codes and logs detailed error messages:

- If an API call fails, the script logs the HTTP code and response body
- Builds are skipped if their information cannot be retrieved
- The script continues processing other builds even if one fails

## Security

- **API Key**: Store your API key securely (use environment variables or secure vaults)
- **Authentication**: Credentials are passed securely via curl's `-u` flag
- **HTTPS**: Always use HTTPS URLs for JFrog connections

## Troubleshooting

### Enable debug mode to see API responses:
```bash
DEBUG="true" ./jfrog-delete-old-builds.sh
```

### Common errors:

**"Missing required tools"**
- Install `jq` and `curl` using the installation instructions above

**"Failed to fetch builds (HTTP 401)"**
- Check your credentials (username and API key)
- Verify the JFROG_URL is correct

**"Failed to fetch builds (HTTP 403)"**
- Verify your user has permission to list and delete builds

**"Could not parse timestamp"**
- Check that the build info is returning valid timestamp data

## License

MIT License - feel free to use and modify this script as needed.
