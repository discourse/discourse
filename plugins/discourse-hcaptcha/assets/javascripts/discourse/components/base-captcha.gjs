// components/base-captcha.gjs
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import InputTip from "discourse/components/input-tip";
import loadScript from "discourse/lib/load-script";
import { i18n } from "discourse-i18n";

export default class BaseCaptcha extends Component {
  @service captchaService;

  @tracked widgetId;
  @tracked configError = "";

  captchaApi = null;

  constructor() {
    super(...arguments);
    this.initializeCaptcha(this.args.siteKey);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    if (this.isCaptchaLoaded()) {
      this.captchaApi.reset(this.widgetId);
    }
  }

  initializeCaptcha(siteKey) {
    if (this.isCaptchaLoaded()) {
      next(() => {
        if (document.getElementById(this.containerId)) {
          this.renderCaptcha(siteKey);
        }
      });
    } else {
      this.loadCaptchaScript(siteKey);
    }
  }


  isCaptchaLoaded() {
    return typeof this.captchaApi !== "undefined";
  }

  async loadCaptchaScript(siteKey) {
    this.beforeScriptLoad(siteKey);

    await loadScript(this.scriptUrl);

    this.afterScriptLoad(siteKey);
  }

  beforeScriptLoad(_siteKey) {}

  afterScriptLoad(siteKey) {
    this.captchaApi = window[this.captchaApiName];
    this.renderCaptcha(siteKey);
  }

  renderCaptcha(siteKey) {
    if (!this.isCaptchaLoaded() || !siteKey) {
      this.configError = i18n(this.configErrorKey);
      return;
    }

    this.widgetId = this.captchaApi.render(this.containerId, {
      sitekey: siteKey,
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


  get configErrorKey() {
    return "discourse_captcha.contact_system_administrator";
  }

  get scriptUrl() {}
  get captchaApiName() {}
  get containerId() {}

  <template>
    <div
      id={{this.containerId}}
      class="captcha-container"
      data-sitekey={{@siteKey}}
    ></div>

    {{#if this.configError}}
      <div class="alert alert-error">
        {{this.configError}}
      </div>
    {{/if}}

    {{#if this.captchaService.submitFailed}}
      <InputTip @validation={{this.captchaService.inputValidation}} />
    {{/if}}
  </template>
}
