import loadScript from "discourse/lib/load-script";
import BaseCaptcha from "./base-captcha";

export default class ReCaptcha extends BaseCaptcha {
  get scriptUrl() {
    return "https://www.google.com/recaptcha/api.js?onload=onloadCallback&render=explicit";
  }

  async loadCaptchaScript() {
    //ReCaptcha calls this once everything has been loaded
    window.onloadCallback = () => {
      this.captchaApi = window.grecaptcha;
      this.renderCaptcha();
    };

    await loadScript(this.scriptUrl);
  }

  get containerId() {
    return "g-recaptcha";
  }

  get configErrorKey() {
    return "discourse_captcha.contact_system_administrator";
  }
}
