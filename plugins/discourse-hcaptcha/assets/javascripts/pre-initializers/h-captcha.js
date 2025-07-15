import { Promise } from "rsvp";
import { ajax } from "discourse/lib/ajax";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { withPluginApi } from "discourse/lib/plugin-api";

const PLUGIN_ID = "discourse-hCaptcha";

function captchaSelector(siteSettings) {
  if (siteSettings.discourse_hcaptcha_enabled) {
    return "hcaptcha";
  } else if (siteSettings.discourse_recaptcha_enabled) {
    return "recaptcha";
  }
}

function initializeHCaptcha(api, container) {
  const siteSettings = container.lookup("service:site-settings");
  if (!siteSettings.discourse_captcha_enabled) {
    return;
  }

  api.modifyClassStatic("model:user", {
    pluginId: PLUGIN_ID,

    createAccount() {
      const captchaService = getOwnerWithFallback(this).lookup(
        "service:captcha-service"
      );
      captchaService.submitted = true;

      if (captchaService.invalid) {
        return Promise.reject();
      }

      const data = {
        token: captchaService.token,
      };

      const captcha_route = captchaSelector(siteSettings);

      const originalAccountCreation = this._super;
      return ajax(`/captcha/${captcha_route}/create.json`, {
        data,
        type: "POST",
      })
        .then(() => {
          return originalAccountCreation(...arguments);
        })
        .catch(() => {
          captchaService.failed = true;
          return Promise.reject();
        })
        .finally(() => {
          captchaService.reset();
        });
    },
  });
}

export default {
  name: "hcaptcha-initializer",
  before: "inject-discourse-objects",

  initialize(container) {
    withPluginApi("1.9.0", (api) => initializeHCaptcha(api, container));
  },
};
