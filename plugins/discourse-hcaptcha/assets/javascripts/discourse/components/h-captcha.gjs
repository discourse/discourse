import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import InputTip from "discourse/components/input-tip";
import loadScript from "discourse/lib/load-script";
import { i18n } from "discourse-i18n";

const HCAPTCHA_SCRIPT_URL = "https://hcaptcha.com/1/api.js?render=explicit";

export default class HCaptcha extends Component {
  @service hCaptchaService;

  @tracked widgetId;
  @tracked invalid = true;
  @tracked hCaptchaConfigError = "";
  hCaptcha;

  constructor() {
    super(...arguments);
    this.initializeHCaptcha(this.args.siteKey);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.isHCaptchaLoaded()) {
      this.hCaptcha.reset(this.widgetId);
    }
  }

  initializeHCaptcha(siteKey) {
    if (this.isHCaptchaLoaded()) {
      next(() => {
        if (document.getElementById("h-captcha-field")) {
          this.renderHCaptcha(siteKey);
        }
      });
      return;
    }

    this.loadHCaptchaScript(siteKey);
  }

  isHCaptchaLoaded() {
    return typeof this.hCaptcha !== "undefined";
  }

  async loadHCaptchaScript(siteKey) {
    await loadScript(HCAPTCHA_SCRIPT_URL);
    this.hCaptcha = window.hcaptcha;
    this.renderHCaptcha(siteKey);
  }

  renderHCaptcha(siteKey) {
    if (!this.isHCaptchaLoaded() || !this.args.siteKey) {
      this.hCaptchaConfigError = i18n(
        "discourse_hCaptcha.contact_system_administrator"
      );
      return;
    }

    this.widgetId = this.hCaptcha.render("h-captcha-field", {
      sitekey: siteKey,
      callback: (response) => {
        this.hCaptchaService.token = response;
        this.hCaptchaService.invalid = !response;
      },
      "expired-callback": () => {
        this.hCaptchaService.invalid = true;
      },
    });

    this.hCaptchaService.registerWidget(this.hCaptcha, this.widgetId);
  }

  <template>
    <div id="h-captcha-field" class="h-captcha" data-sitekey={{@sitekey}}></div>

    {{#if this.hCaptchaConfigError}}
      <div class="alert alert-error">
        {{this.hCaptchaConfigError}}
      </div>
    {{/if}}

    {{#if this.hCaptchaService.submitFailed}}
      <InputTip @validation={{this.hCaptchaService.inputValidation}} />
    {{/if}}
  </template>
}
