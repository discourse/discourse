# Discourse Captcha Plugin

## Overview

This plugin integrates captcha verification into the sign-up form of Discourse forums to enhance security and bot protection. The plugin supports three captcha providers:

- **hCaptcha**: Privacy-centric captcha service
- **reCaptcha v2**: Google's visible captcha widget
- **reCaptcha v3**: Google's invisible, score-based captcha

You can enable one provider based on your preference and requirements.

## Installation

### For hCaptcha

1. **Create an hCaptcha Account**:
   - Visit [hCaptcha](https://www.hcaptcha.com/) to create an account. After registering, you'll receive a site key and a secret key.

2. **Configure Plugin Settings**:
   - Log into your Discourse admin panel.
   - Navigate to `Admin` > `Settings` > `Plugins` > `Captcha Plugin`.
   - Enable the master toggle: `discourse_captcha_enabled`
   - Select `hcaptcha` in the `discourse_captcha_provider` setting.
   - Add the site key and secret key you obtained from hCaptcha.

### For reCaptcha v2 or v3

1. **Create a reCaptcha Account**:
   - Visit [Google reCaptcha](https://www.google.com/recaptcha) to register your site. After registering, you'll receive a site key and a secret key.

2. **Configure Plugin Settings**:
   - Log into your Discourse admin panel.
   - Navigate to `Admin` > `Settings` > `Plugins` > `Captcha Plugin`.
   - Enable the master toggle: `discourse_captcha_enabled`
   - Select `recaptcha_v2` (v2) or `recaptcha_v3` in the `discourse_captcha_provider` setting.
   - Add the site key and secret key you obtained from reCaptcha. For v3 you can also adjust the minimum accepted score with `recaptcha_v3_score_threshold`.

## Testing saved keys

The plugin must be enabled to test saved keys from the **Test** tab on its admin page.
