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

2. **Setup Local Testing** (Optional):
   - If you are testing locally, add a new virtual host entry to your hosts file. Include a line like `127.0.0.1 test.mydomain.com`. Make sure the domain is valid, even if you don't own it, to ensure the hCaptcha script loads properly.

3. **Configure Plugin Settings**:
   - Log into your Discourse admin panel.
   - Navigate to `Admin` > `Settings` > `Plugins` > `Captcha Plugin`.
   - Enable the master toggle: `discourse_captcha_enabled`
   - Enable `discourse_hcaptcha_enabled`
   - Add the site key and secret key you obtained from hCaptcha.

### For reCaptcha

1. **Create a reCaptcha Account**:
   - Visit [Google reCaptcha](https://www.google.com/recaptcha) to register your site. After registering, you'll receive a site key and a secret key.

2. **Configure Plugin Settings**:
   - Log into your Discourse admin panel.
   - Navigate to `Admin` > `Settings` > `Plugins` > `Captcha Plugin`.
   - Enable the master toggle: `discourse_captcha_enabled`
   - Enable `discourse_recaptcha_enabled`
   - Add the site key and secret key you obtained from reCaptcha.

## Migration Notes

If you were using this plugin when it was named "discourse-hcaptcha", your existing settings have been automatically migrated. The old `discourse_hcaptcha_enabled` setting still works but is deprecated and will be removed in version 3.5. Please update your configuration to use `discourse_captcha_enabled` as the master toggle.
