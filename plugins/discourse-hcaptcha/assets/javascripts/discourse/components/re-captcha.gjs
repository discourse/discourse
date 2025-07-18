import BaseCaptcha from "./base-captcha";

export default class ReCaptcha extends BaseCaptcha {
  get scriptUrl() {
    return "https://www.google.com/recaptcha/api.js?onload=onloadCallback&render=explicit";
  }

  get globalObjectName() {
    return "grecaptcha";
  }

  get globalCallbackName() {
    return "onloadCallback";
  }

  beforeScriptLoad(siteKey) {
    //ReCaptcha calls this once everything has been loaded
    window[this.globalCallbackName] = () => {
      this.captchaApi = window[this.globalObjectName];
      this.renderCaptcha(siteKey);
    };
  }

  afterScriptLoad(_siteKey) {
    // Do nothing Already rendered in beforeScriptLoad
  }

  get containerId() {
    return "g-recaptcha";
  }

  get configErrorKey() {
    return "discourse_captcha.contact_system_administrator";
  }
}
