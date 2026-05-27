import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import loadScript from "discourse/lib/load-script";
import DInputTip from "discourse/ui-kit/d-input-tip";
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
  }

  initializeCaptcha() {
    if (this.isCaptchaLoaded) {
      this.captchaApi = window[this.captchaApiName];
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
    return typeof window[this.captchaApiName] !== "undefined";
  }

  renderCaptcha() {
    if (!this.isCaptchaLoaded || !this.siteKey) {
      this.captchaError = i18n(this.captchaErrorKey);
      return;
    }

    const renderOptions = {
      sitekey: this.siteKey,
      callback: (response) => {
        this.captchaService.token = response;
        this.captchaService.invalid = !response;
      },
      "expired-callback": () => {
        this.captchaService.invalid = true;
      },
      ...this.additionalRenderOptions(),
    };

    this.widgetId = this.captchaApi.render(this.containerId, renderOptions);

    this.captchaService.registerWidget(this.captchaApi, this.widgetId);
  }

  additionalRenderOptions() {
    return {};
  }

  async loadCaptchaScript() {
    try {
      window[this.callbackName] = () => {
        this.captchaApi = window[this.captchaApiName];
        this.renderCaptcha();
      };

      await loadScript(this.scriptUrl);
    } catch (error) {
      // eslint-disable-next-line no-console
      console.error(`Failed to load ${this.providerName} script:`, error);
      this.captchaError = i18n(this.captchaErrorKey);
    }
  }

  get captchaErrorKey() {
    return "discourse_captcha.contact_system_administrator";
  }

  get scriptUrl() {
    throw new Error("Subclasses must implement 'scriptUrl'");
  }

  get callbackName() {
    throw new Error("Subclasses must implement 'callbackName'");
  }

  get captchaApiName() {
    throw new Error("Subclasses must implement 'captchaApiName'");
  }

  get providerName() {
    throw new Error("Subclasses must implement 'providerName'");
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
      <DInputTip @validation={{this.captchaService.inputValidation}} />
    {{/if}}
  </template>
}
