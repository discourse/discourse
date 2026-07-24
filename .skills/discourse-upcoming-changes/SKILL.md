---
name: discourse-upcoming-changes
description: Use when adding a new upcoming change feature flag to Discourse - handles site settings, translations, images, and code access patterns
---

# Adding Discourse Upcoming Changes

## Overview

Upcoming changes are feature flags that allow gradual rollout of new Discourse features. They require a site setting, translation, optional image, and can be targeted to specific groups.

## When to Use

Use when:

- Adding a new feature that needs gradual rollout
- Creating an experimental/alpha/beta feature flag

## Checklist

### 0. Gather Required Information

**REQUIRED:** Before adding the site setting, use AskUserQuestion to gather missing information. Only ask questions for information the user has NOT already provided. The user can always type a value directly via the "Other" option.

**Batch 1** (ask first, max 4 questions):

| Question    | Header   | Options                                                                         |
| ----------- | -------- | ------------------------------------------------------------------------------- |
| Status      | "Status" | "conceptual" (Planned, hidden) / "experimental" (Very early) / "alpha" (Internal) / "beta" (Broader) |
| Impact Type | "Impact" | "feature" (New functionality) / "other" (Non-feature change)                    |
| Audience    | "Audience" | "all_members" / "staff" / "moderators" / "admin"                              |
| Image       | "Image"  | "No image needed" / "I'll provide the path later"                               |

Note: For Status, "stable" and "permanent" are available via "Other". For Audience, "developers" is available via "Other".

**After Batch 1:** Gather any remaining information before continuing:
- If the flag name was not provided in the original message, ask for it
- If the user selected "I'll provide the path later" for Image, ask for the image path
- Ask if they have a Learn More URL to link to

### 1. Add Site Setting

**IMPORTANT:** Do NOT read the entire `config/site_settings.yml` file - it's too large. Instead, use Grep to search for `upcoming_change:` to find existing examples and the right location to add the new setting.

Add to `config/site_settings.yml` in the appropriate section (often under `experimental:`):

```yaml
enable_your_feature_name:
  default: false
  hidden: true
  client: true
  upcoming_change:
    status: "<status from question>"
    impact: "<type>,<audience>"
    learn_more_url: "<URL from question>"
```

**Status options:** `conceptual`, `experimental`, `alpha`, `beta`, `stable`, `permanent`

**Impact format:** `<type>,<audience>`

- Type: `feature` or `other`
- Audience: `admin`, `moderators`, `staff`, `all_members`, `developers`

**Learn more URL:** Add `learn_more_url: "https://..."` for documentation link. This should generally be a Discourse Meta URL in the format https://meta.discourse.org/t/-/999999 . If the user pastes a topic URL with a slug, remove the slug and replace with a `-` as shown.

**Optional:** Add `allow_enabled_for:` to restrict which "Enabled for" dropdown options the admin can choose. Accepts any subset of `everyone`, `staff`, `specific_groups`. "No one" is always available. If `everyone` is included it must be the only value. Omit the key to allow all options (the default).

```yaml
upcoming_change:
  status: "experimental"
  impact: "feature,all_members"
  allow_enabled_for:
    - staff
    - specific_groups
```

| Value | Dropdown options |
|---|---|
| *(omitted)* | No one, Everyone, Staff, Specific group(s) |
| `[everyone]` | No one, Everyone |
| `[staff]` | No one, Staff |
| `[specific_groups]` | No one, Specific group(s) |
| `[staff, specific_groups]` | No one, Staff, Specific group(s) |

**Optional:** Add `include_css: true` if you need to scope CSS to this change. When enabled for a user, a `uc-<dasherized-setting-name>` class is added to `<body>` so stylesheets can gate visuals on the change (e.g. `enable_your_feature_name` → `body.uc-enable-your-feature-name`). Omit it (the default) when the change has no CSS keyed on the body class — body classes are opt-in, not emitted for every change. Always scope this CSS as `:where(.uc-<dasherized-setting-name>)`, never a bare `.uc-<name>`, so the transitional class adds zero specificity and stays safe to remove later — enforced by the `discourse/uc-classes-in-where` stylelint rule.

```yaml
upcoming_change:
  status: "experimental"
  impact: "feature,all_members"
  include_css: true
```

**Optional:** Add `permanent_warning: false` to suppress the "This change will become permanent soon. You will no longer be able to opt-out." notice that is shown on the admin page once the change reaches `stable`. The notice is shown by default for every change; opt out only when it is misleading — typically changes that just flip the default value of another site setting (`impact: "site_setting_default,..."`), which admins can always set back afterwards.

```yaml
upcoming_change:
  status: "stable"
  impact: "site_setting_default,all_members"
  permanent_warning: false
```

### 2. Add Translation

Add to `config/locales/server.en.yml` under `site_settings:`:

```yaml
en:
  site_settings:
    enable_your_feature_name: "Description of what this upcoming change enables or modifies"
```

### 3. Add Preview Image

Ask user to provide an image, then process it using the skill's optimization script:

1. **Copy image to destination:**

   ```bash
   cp "<source_image>" "public/images/upcoming_changes/<setting_name>.png"
   ```

2. **Convert, resize, and compress** using the skill's optimization script:

   ```bash
   bin/rails runner ~/.claude/skills/discourse-upcoming-changes/scripts/optimize_upcoming_change_image.rb public/images/upcoming_changes/<setting_name>.png
   ```

   This script:

   - Converts any image format to PNG using Discourse's ImageMagick integration
   - Resizes to max 1200px width using `OptimizedImage.downsize`
   - Compresses with pngquant via `FileHelper.optimize_image!`

3. **Final path:** `public/images/upcoming_changes/<setting_name>.png`
   - Filename must match the setting name exactly

### 4. Access in Code

**Ruby - Check if enabled for user:**

```ruby
user.upcoming_change_enabled?(:enable_your_feature_name)

# Or with explicit user (nil for anonymous):
UpcomingChanges.enabled_for_user?(:enable_your_feature_name, user)
UpcomingChanges.enabled_for_user?(:enable_your_feature_name, nil)
```

**JavaScript - Check setting value:**

```javascript
// In component/controller with @service siteSettings
this.siteSettings.enable_your_feature_name;
```

## For Plugins

Plugins follow the same pattern with different file locations.

### 1. Add Site Setting

Add to `plugins/your-plugin/config/settings.yml`:

```yaml
plugins:
  enable_your_feature_name:
    default: false
    hidden: true
    client: true
    upcoming_change:
      status: "experimental"
      impact: "feature,all_members"
```

### 2. Add Translation

Add to `plugins/your-plugin/config/locales/server.en.yml`:

```yaml
en:
  site_settings:
    enable_your_feature_name: "Description of what this upcoming change enables or modifies"
```

### 3. Image

Images still go in core: `public/images/upcoming_changes/enable_your_feature_name.png`

## Quick Reference

| Item         | Core Location                               | Plugin Location                               |
| ------------ | ------------------------------------------- | --------------------------------------------- |
| Site setting | `config/site_settings.yml`                  | `plugins/<name>/config/settings.yml`          |
| Translation  | `config/locales/server.en.yml`              | `plugins/<name>/config/locales/server.en.yml` |
| Image        | `public/images/upcoming_changes/<name>.png` | Same as core                                  |

| Status       | Value | Description                              |
| ------------ | ----- | ---------------------------------------- |
| conceptual   | -100  | Planned but hidden from upcoming changes |
| experimental | 0     | Very early testing                       |
| alpha        | 100   | Internal testing                         |
| beta         | 200   | Broader testing                          |
| stable       | 300   | Ready for production                     |
| permanent    | 500   | Permanent feature                        |

## Common Mistakes

| Mistake                          | Fix                                              |
| -------------------------------- | ------------------------------------------------ |
| Missing `client: true`           | Add it - required for JS access                  |
| Missing `hidden: true`           | Add it - upcoming changes should be hidden       |
| Image name mismatch              | Filename must exactly match setting name         |
| Image too large (>300KB)         | Re-run the optimization script                   |
| Wrong translation key            | Must be under `en.site_settings.`                |
| Plugin using `site_settings.yml` | Plugins use `settings.yml` (no `site_` prefix)   |
| Plugin missing `plugins:` key    | Settings must be under `plugins:` key in plugins |
