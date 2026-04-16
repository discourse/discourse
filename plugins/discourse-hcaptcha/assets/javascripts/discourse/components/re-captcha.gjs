import loadScript from "discourse/lib/load-script";
import BaseCaptcha from "./base-captcha";

export default class ReCaptcha extends BaseCaptcha {
  get scriptUrl() {
    return "https://www.google.com/recaptcha/api.js?onload=discourseReCaptchaCallback&render=explicit";
  }

  async loadCaptchaScript() {
    try {
      //ReCaptcha calls this once everything has been loaded
      window.discourseReCaptchaCallback = () => {
        this.captchaApi = window.grecaptcha;
        this.renderCaptcha();
      };

      await loadScript(this.scriptUrl);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error("Failed to load reCaptcha script:", error);
      this.captchaError = this.captchaErrorKey;
    }
  }

  get containerId() {
    return "g-recaptcha";
  }
}
