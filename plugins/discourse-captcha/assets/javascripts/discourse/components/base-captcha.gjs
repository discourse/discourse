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
        if (this.args.onResponse) {
          this.args.onResponse(response);
          return;
        }
        this.captchaService.token = response;
        this.captchaService.invalid = !response;
      },
      "expired-callback": () => {
        if (this.args.onResponse) {
          this.args.onResponse(null);
          return;
        }
        this.captchaService.invalid = true;
      },
      ...this.additionalRenderOptions(),
      ...(this.args.onError && { "error-callback": this.args.onError }),
    };

    let active = true;
    ["callback", "expired-callback", "error-callback"].forEach((name) => {
      const callback = renderOptions[name];
      if (callback) {
        renderOptions[name] = (...args) => {
          if (active) {
            return callback(...args);
          }
        };
      }
    });

    const widgetId = captchaApi.render(element, renderOptions);
    this.widgetId = widgetId;
    if (!this.args.onResponse) {
      this.captchaService.registerWidget(captchaApi, this.widgetId);
    }

    const standalone = Boolean(this.args.onResponse);
    return () => {
      active = false;
      if (standalone) {
        if (captchaApi.remove) {
          captchaApi.remove(widgetId);
        } else {
          captchaApi.reset?.(widgetId);
        }
      }
    };
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

      loadScript(this.scriptUrl).catch((error) => {
        if (!this.isDestroying) {
          this.args.onError?.();
        }
        reject(error);
      });
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
          class="captcha-container"
          data-sitekey={{@siteKey}}
          id={{this.containerId}}
          {{this.renderCaptcha captchaApi=captchaApi}}
        ></div>
      </:content>
      <:error>
        {{#unless @onError}}
          <div class="alert alert-error">
            {{if @errorMessage @errorMessage (i18n this.captchaErrorKey)}}
          </div>
        {{/unless}}
      </:error>
    </DAsyncContent>

    {{#unless @onResponse}}
      {{#if this.captchaService.submitFailed}}
        <DInputTip @validation={{this.captchaService.inputValidation}} />
      {{/if}}
    {{/unless}}
  </template>
}
