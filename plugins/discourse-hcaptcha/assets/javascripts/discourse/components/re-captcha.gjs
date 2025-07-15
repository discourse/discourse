import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import InputTip from "discourse/components/input-tip";
import loadScript from "discourse/lib/load-script";
import { i18n } from "discourse-i18n";

const RECAPTCHA_SCRIPT_URL =
  "https://www.google.com/recaptcha/api.js?onload=onloadCallback&render=explicit";

export default class ReCaptcha extends Component {
  @service captchaService;

  @tracked widgetId;
  @tracked invalid = true;
  @tracked reCaptchaConfigError = "";
  reCaptcha;

  constructor() {
    super(...arguments);
    this.initializeReCaptcha(this.args.siteKey);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.isReCaptchaLoaded()) {
      this.reCaptcha.reset(this.widgetId);
    }
  }

  initializeReCaptcha(siteKey) {
    if (this.isReCaptchaLoaded()) {
      next(() => {
        if (document.getElementById("g-recaptcha")) {
          this.renderReCaptcha(siteKey);
        }
      });
      return;
    }

    this.loadReCaptchaScript(siteKey);
  }

  isReCaptchaLoaded() {
    return typeof this.reCaptcha !== "undefined";
  }

  async loadReCaptchaScript(siteKey) {
    //ReCaptcha calls this once everything has been loaded
    window.onloadCallback = () => {
      this.reCaptcha = window.grecaptcha;
      this.renderReCaptcha(siteKey);
    };

    await loadScript(RECAPTCHA_SCRIPT_URL);
  }

  renderReCaptcha(siteKey) {
    if (!this.isReCaptchaLoaded() || !this.args.siteKey) {
      this.reCaptchaConfigError = i18n(
        "discourse_reCaptcha.contact_system_administrator"
      );
      return;
    }

    this.widgetId = this.reCaptcha.render("g-recaptcha", {
      sitekey: siteKey,
      callback: (response) => {
        this.captchaService.token = response;
        this.captchaService.invalid = !response;
      },
      "expired-callback": () => {
        this.reCaptchaService.invalid = true;
      },
    });

    this.captchaService.registerWidget(this.reCaptcha, this.widgetId);
  }

  <template>
    <div id="g-recaptcha" class="h-captcha" data-sitekey={{@sitekey}}></div>

    {{#if this.reCaptchaConfigError}}
      <div class="alert alert-error">
        {{this.reCaptchaConfigError}}
      </div>
    {{/if}}

    {{#if this.captchaService.submitFailed}}
      <InputTip @validation={{this.captchaService.inputValidation}} />
    {{/if}}
  </template>
}
