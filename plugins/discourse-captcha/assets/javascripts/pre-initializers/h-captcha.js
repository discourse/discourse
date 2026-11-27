import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";

function captchaSelector(siteSettings) {
  if (siteSettings.discourse_captcha_provider !== "none") {
    return siteSettings.discourse_captcha_provider;
  } else {
    return false;
  }
}

function initializeHCaptcha(api, container) {
  const siteSettings = container.lookup("service:site-settings");

  if (
    !siteSettings.discourse_captcha_enabled ||
    !captchaSelector(siteSettings)
  ) {
    return;
  }

  const withCaptcha = async (next) => {
    const captchaService = container.lookup("service:captcha-service");
    captchaService.submitted = true;

    if (captchaService.refreshToken) {
      await captchaService.refreshToken();
    }

    if (captchaService.invalid) {
      return {
        success: false,
        message: i18n("discourse_captcha.missing_token"),
      };
    }

    const captchaRoute = captchaSelector(siteSettings);

    try {
      await ajax(`/captcha/${captchaRoute}/create.json`, {
        data: { token: captchaService.token },
        type: "POST",
      });
    } catch {
      captchaService.reset();
      return {
        success: false,
        message: i18n("discourse_captcha.verification_failed"),
      };
    }

    try {
      return await next();
    } finally {
      captchaService.reset();
    }
  };

  // The challenge is solved before the code is emailed. Resending to the same
  // address reuses that solve, and invitations are never challenged.
  api.registerBehaviorTransformer("request-login-code", ({ next, context }) => {
    if (context?.isInvite || context?.resend) {
      return next();
    }

    return withCaptcha(next);
  });

  api.registerBehaviorTransformer("create-account", ({ next, context }) => {
    // Code login signups already solved the challenge before the code was sent.
    if (context?.codeLogin) {
      return next();
    }

    return withCaptcha(next);
  });
}

export default {
  name: "hcaptcha-initializer",
  before: "inject-discourse-objects",

  initialize(container) {
    withPluginApi((api) => initializeHCaptcha(api, container));
  },
};
