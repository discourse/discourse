import BaseCaptcha from "./base-captcha";

export default class ReCaptcha extends BaseCaptcha {
  get scriptUrl() {
    return "https://www.google.com/recaptcha/api.js?onload=discourseReCaptchaCallback&render=explicit";
  }

  get callbackName() {
    return "discourseReCaptchaCallback";
  }

  get captchaApiName() {
    return "grecaptcha";
  }

  get providerName() {
    return "reCaptcha";
  }

  get containerId() {
    return "g-recaptcha";
  }
}
