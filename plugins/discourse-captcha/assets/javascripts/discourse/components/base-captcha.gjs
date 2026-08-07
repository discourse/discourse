import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import { modifier as modifierFn } from "ember-modifier";
import { bind } from "discourse/lib/decorators";
import loadScript from "discourse/lib/load-script";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DInputTip from "discourse/ui-kit/d-input-tip";
import { i18n } from "discourse-i18n";

export default class BaseCaptcha extends Component {
  @service captchaService;

  @tracked widgetId;

  renderCaptcha = modifierFn((element, _, { captchaApi }) => {
    if (!captchaApi || !this.siteKey) {
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

    this.widgetId = captchaApi.render(element, renderOptions);
    this.captchaService.registerWidget(captchaApi, this.widgetId);
  });

  get siteKey() {
    return this.args.siteKey;
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

  @bind
  async loadCaptchaScript() {
    if (window[this.captchaApiName]) {
      return window[this.captchaApiName];
    }

    return new Promise((resolve, reject) => {
      window[this.callbackName] = () => {
        resolve(window[this.captchaApiName]);
      };

      loadScript(this.scriptUrl).catch(reject);
    });
  }

  additionalRenderOptions() {
    return {};
  }

  <template>
    <DAsyncContent @asyncData={{this.loadCaptchaScript}}>
      <:loading>
        <div class="captcha-container captcha-loading">
          {{i18n "loading"}}
        </div>
      </:loading>
      <:content as |captchaApi|>
        <div
          id={{this.containerId}}
          class="captcha-container"
          data-sitekey={{@siteKey}}
          {{this.renderCaptcha captchaApi=captchaApi}}
        ></div>
      </:content>
      <:error>
        <div class="alert alert-error">
          {{i18n this.captchaErrorKey}}
        </div>
      </:error>
    </DAsyncContent>

    {{#if this.captchaService.submitFailed}}
      <DInputTip @validation={{this.captchaService.inputValidation}} />
    {{/if}}
  </template>
}
