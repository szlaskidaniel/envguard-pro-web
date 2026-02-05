# Marketing ads

This folder contains source HTML used to render 1600×1200 PNG ad images for EnvGuard Pro.

## Render PNGs (Recommended)

From the repo root:

```bash
mkdir -p /tmp/swift-module-cache /tmp/clang-module-cache
env SWIFT_MODULE_CACHE_PATH=/tmp/swift-module-cache \
  CLANG_MODULE_CACHE_PATH=/tmp/clang-module-cache \
  swift scripts/render_ads.swift
```

## HTML sources (Optional)

The layouts are also saved as static HTML for easy tweaking:

- `marketing/ads/ad-1-ci-dashboard.html`
- `marketing/ads/ad-2-aws-sarif.html`

## Verify dimensions

```bash
sips -g pixelWidth -g pixelHeight marketing/ads/envguard-pro-ad-1.png
sips -g pixelWidth -g pixelHeight marketing/ads/envguard-pro-ad-2.png
```
