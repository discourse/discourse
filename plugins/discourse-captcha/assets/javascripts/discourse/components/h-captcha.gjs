import BaseCaptcha from "./base-captcha";

export default class HCaptcha extends BaseCaptcha {
  get scriptUrl() {
    return "https://js.hcaptcha.com/1/api.js?onload=discourseHCaptchaCallback&render=explicit";
  }

  get callbackName() {
    return "discourseHCaptchaCallback";
  }

  get captchaApiName() {
    return "hcaptcha";
  }

  get providerName() {
    return "hCaptcha";
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
}
