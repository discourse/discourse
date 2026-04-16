import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import InputTip from "discourse/components/input-tip";
import { i18n } from "discourse-i18n";

export default class BaseCaptcha extends Component {
  @service captchaService;

  @tracked widgetId;
  @tracked captchaError = "";

  siteKey = this.args.siteKey;
  captchaApi;

  constructor() {
    super(...arguments);
    this.initializeCaptcha();
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.isCaptchaLoaded) {
      this.captchaApi.reset(this.widgetId);
    }
  }

  initializeCaptcha() {
    if (this.isCaptchaLoaded) {
      next(() => {
        if (document.getElementById(this.containerId)) {
          this.renderCaptcha(this.siteKey);
        }
      });
    } else {
      this.loadCaptchaScript(this.siteKey);
    }
  }

  get isCaptchaLoaded() {
    return typeof this.captchaApi !== "undefined";
  }

  renderCaptcha() {
    if (!this.isCaptchaLoaded || !this.siteKey) {
      this.captchaError = i18n(this.captchaErrorKey);
      return;
    }

    this.widgetId = this.captchaApi.render(this.containerId, {
      sitekey: this.siteKey,
      callback: (response) => {
        this.captchaService.token = response;
        this.captchaService.invalid = !response;
      },
      "expired-callback": () => {
        this.captchaService.invalid = true;
      },
    });

    this.captchaService.registerWidget(this.captchaApi, this.widgetId);
  }

  async loadCaptchaScript() {
    throw new Error("Subclasses must implement 'loadCaptchaScript'");
  }

  get captchaErrorKey() {
    return "discourse_captcha.contact_system_administrator";
  }

  get scriptUrl() {
    throw new Error("Subclasses must implement 'scriptUrl'");
  }

  get captchaApiName() {
    throw new Error("Subclasses must implement 'captchaApiName'");
  }

  get containerId() {
    throw new Error("Subclasses must implement 'containerId'");
  }

  <template>
    <div
      id={{this.containerId}}
      class="captcha-container"
      data-sitekey={{@siteKey}}
    ></div>

    {{#if this.captchaError}}
      <div class="alert alert-error">
        {{this.captchaError}}
      </div>
    {{/if}}

    {{#if this.captchaService.submitFailed}}
      <InputTip @validation={{this.captchaService.inputValidation}} />
    {{/if}}
  </template>
}
