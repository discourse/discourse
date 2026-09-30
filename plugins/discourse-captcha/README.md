# Discourse Captcha Plugin

## Overview

This plugin integrates captcha verification into the sign-up form of Discourse forums to enhance security and bot protection. The plugin supports two captcha providers:

- **hCaptcha**: Privacy-centric captcha service
- **reCaptcha**: Google's captcha service

You can enable either provider based on your preference and requirements.

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

### For reCaptcha

1. **Create a reCaptcha Account**:
   - Visit [Google reCaptcha](https://www.google.com/recaptcha) to register your site. After registering, you'll receive a site key and a secret key.

2. **Configure Plugin Settings**:
   - Log into your Discourse admin panel.
   - Navigate to `Admin` > `Settings` > `Plugins` > `Captcha Plugin`.
   - Enable the master toggle: `discourse_captcha_enabled`
   - Select `recaptcha` in the `discourse_captcha_provider` setting.
   - Add the site key and secret key you obtained from reCaptcha.

## Testing saved keys

Admins can open **Test** on the CAPTCHA plugin's admin page to test
the selected provider with the saved site key and secret key. Click **Test configuration**, then complete the challenge
to verify the keys with the provider. The test works with registration enforcement
disabled and does not create an account or authorize a registration.

The test runs on the current site's domain, which must be allowed by the provider.
reCAPTCHA keys must support the v2 checkbox challenge. The secret key stays on the
server. Provider errors, expired challenges, and connection failures are displayed
in the test section; a successful test confirms the configuration at that moment.

## Migration Notes

If you were using this plugin when it was named "discourse-hcaptcha", your existing settings have been automatically migrated.
