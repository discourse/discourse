import { ajax } from "discourse/lib/ajax";
import { withPluginApi } from "discourse/lib/plugin-api";

function captchaSelector(siteSettings) {
  if (siteSettings.discourse_hcaptcha_enabled) {
    return "hcaptcha";
  } else if (siteSettings.discourse_recaptcha_enabled) {
    return "recaptcha";
  }
}

function initializeHCaptcha(api, container) {
  const siteSettings = container.lookup("service:site-settings");
  if (!captchaSelector(siteSettings)) {
    return;
  }

  api.registerValueTransformer("before-create-account", async () => {
    const captchaService = container.lookup("service:captcha-service");
    captchaService.submitted = true;

    if (captchaService.invalid) {
      return false;
    }

    const captchaRoute = captchaSelector(siteSettings);

    try {
      await ajax(`/captcha/${captchaRoute}/create.json`, {
        data: { token: captchaService.token },
        type: "POST",
      });
      return true;
    } catch {
      captchaService.failed = true;
      return false;
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
