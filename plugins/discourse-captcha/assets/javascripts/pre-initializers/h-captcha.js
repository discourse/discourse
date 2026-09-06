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

  api.registerBehaviorTransformer("create-account", async ({ next }) => {
    const captchaService = container.lookup("service:captcha-service");
    captchaService.submitted = true;

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
  });
}

export default {
  name: "hcaptcha-initializer",
  before: "inject-discourse-objects",

  initialize(container) {
    withPluginApi((api) => initializeHCaptcha(api, container));
  },
};
