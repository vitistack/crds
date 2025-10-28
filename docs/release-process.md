# Release Process

This document describes how to create a new release of the Vitistack CRDs.

## Prerequisites

- Write access to the repository
- All changes merged to `main` branch
- Tests passing on main

## Release Steps

### 1. Determine the Version

Follow [Semantic Versioning](https://semver.org/):

- **MAJOR**: Incompatible API changes
- **MINOR**: New functionality in a backwards compatible manner
- **PATCH**: Backwards compatible bug fixes

### 2. Create and Push a Version Tag

```bash
# Make sure you're on the latest main branch
git checkout main
git pull origin main

# Create a version tag (e.g., v0.1.0)
VERSION="v0.1.0"
git tag -a ${VERSION} -m "Release ${VERSION}"

# Push the tag to GitHub
git push origin ${VERSION}
```

### 3. Automated Release Process

Once the tag is pushed, the GitHub Actions workflow will automatically:

1. ✅ Run `make generate` to generate the latest CRDs
2. ✅ Run `make build` to verify the build
3. ✅ Run `make test` to ensure all tests pass
4. ✅ Run `make verify-crds` to validate CRDs are properly sanitized
5. ✅ Copy CRDs from `./crds` to `charts/vitistack-crds/templates/`
6. ✅ Update the Helm chart version in `Chart.yaml`
7. ✅ Lint the Helm chart
8. ✅ Package the Helm chart
9. ✅ Push the chart as an OCI image to `ghcr.io/vitistack/vitistack-crds`
10. ✅ Create a GitHub Release with the packaged chart attached

### 4. Monitor the Release

1. Go to the [Actions tab](https://github.com/vitistack/crds/actions) in GitHub
2. Watch the "Release Helm Chart" workflow
3. Verify all steps complete successfully

### 5. Verify the Release

Once the workflow completes:

**Check GitHub Release:**

```bash
# Visit: https://github.com/vitistack/crds/releases
```

**Check OCI Registry:**

```bash
# View packages: https://github.com/orgs/vitistack/packages?repo_name=crds

# Pull the chart
helm pull oci://ghcr.io/vitistack/vitistack-crds --version 0.1.0

# Or install directly
helm install test-crds oci://ghcr.io/vitistack/vitistack-crds --version 0.1.0
```

## Pre-release Versions

For alpha, beta, or RC releases, append the suffix to the version:

```bash
# Alpha release
git tag -a v0.2.0-alpha.1 -m "Release v0.2.0-alpha.1"

# Beta release
git tag -a v0.2.0-beta.1 -m "Release v0.2.0-beta.1"

# Release candidate
git tag -a v0.2.0-rc.1 -m "Release v0.2.0-rc.1"

git push origin <tag-name>
```

Pre-releases will be marked as such in the GitHub Release.

## Rollback a Release

If you need to rollback a release:

1. **Delete the GitHub Release** (via GitHub UI)
2. **Delete the Git tag:**
   ```bash
   git tag -d v0.1.0
   git push origin :refs/tags/v0.1.0
   ```
3. **Note:** You cannot delete OCI images from ghcr.io, but you can mark them as deprecated

## Troubleshooting

### Workflow Fails

1. Check the workflow logs in the Actions tab
2. Fix any issues in the code
3. Delete the tag: `git tag -d v0.1.0 && git push origin :refs/tags/v0.1.0`
4. Fix the issues and create a new tag

### Chart Not Found in Registry

- Wait a few minutes for the registry to sync
- Check the workflow completed successfully
- Verify you have read access to the package

### Installation Fails

```bash
# Check if the chart exists
helm show chart oci://ghcr.io/vitistack/vitistack-crds --version 0.1.0

# Pull and inspect
helm pull oci://ghcr.io/vitistack/vitistack-crds --version 0.1.0
tar -xzf vitistack-crds-0.1.0.tgz
cat vitistack-crds/Chart.yaml
```

## Post-Release Tasks

After a successful release:

1. ✅ Update documentation if needed
2. ✅ Announce the release (if applicable)
3. ✅ Update any dependent projects
4. ✅ Close related issues and PRs

## Release Cadence

- **Patch releases**: As needed for bug fixes
- **Minor releases**: Monthly or when new features are ready
- **Major releases**: As needed for breaking changes
