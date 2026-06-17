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

## Migration Notes

If you were using this plugin when it was named "discourse-hcaptcha", your existing settings have been automatically migrated.
