import loadScript from "discourse/lib/load-script";
import BaseCaptcha from "./base-captcha";

export default class HCaptcha extends BaseCaptcha {
  get scriptUrl() {
    return "https://hcaptcha.com/1/api.js?render=explicit";
  }

  get containerId() {
    return "h-captcha-field";
  }

  get configErrorKey() {
    return "discourse_captcha.contact_system_administrator";
  }

  async loadCaptchaScript() {
    await loadScript(this.scriptUrl);

    this.captchaApi = window.hcaptcha;
    this.renderCaptcha(this.siteKey);
  }
}
