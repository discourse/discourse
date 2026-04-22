import loadScript from "discourse/lib/load-script";
import BaseCaptcha from "./base-captcha";

export default class HCaptcha extends BaseCaptcha {
  get scriptUrl() {
    return "https://js.hcaptcha.com/1/api.js?onload=discourseHCaptchaCallback&render=explicit";
  }

  get containerId() {
    return "h-captcha-field";
  }

  additionalRenderOptions() {
    return {
      "error-callback": (error) => {
        // eslint-disable-next-line no-console
        console.error("hCaptcha error:", error);
        this.captchaService.invalid = true;
      },
    };
  }

  async loadCaptchaScript() {
    try {
      window.discourseHCaptchaCallback = () => {
        this.captchaApi = window.hcaptcha;
        this.renderCaptcha();
      };

      await loadScript(this.scriptUrl);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Failed to load hCaptcha script:", error);
      this.captchaError = this.captchaErrorKey;
    }
  }
}
