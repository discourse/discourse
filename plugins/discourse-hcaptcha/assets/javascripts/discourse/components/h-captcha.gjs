import loadScript from "discourse/lib/load-script";
import BaseCaptcha from "./base-captcha";

export default class HCaptcha extends BaseCaptcha {
  get scriptUrl() {
    return "https://hcaptcha.com/1/api.js?render=explicit";
  }

  get containerId() {
    return "h-captcha-field";
  }

  async loadCaptchaScript() {
    try {
      await loadScript(this.scriptUrl);
      this.captchaApi = window.hcaptcha;
      this.renderCaptcha(this.siteKey);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Failed to load hCaptcha script:", error);
      this.captchaError = this.captchaErrorKey;
    }
  }
}
