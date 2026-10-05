import { modifier as modifierFn } from "ember-modifier";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DInputTip from "discourse/ui-kit/d-input-tip";
import { i18n } from "discourse-i18n";
import BaseCaptcha from "./base-captcha";

export default class ReCaptchaV3 extends BaseCaptcha {
  registerCaptcha = modifierFn((_element, _args, { captchaApi }) => {
    let active = true;
    if (this.args.onResponse) {
      captchaApi.execute(this.siteKey, { action: "configuration_test" }).then(
        (token) => {
          if (active) {
            this.args.onResponse(token);
          }
        },
        () => {
          if (active) {
            this.args.onError?.();
          }
        }
      );
      return () => {
        active = false;
      };
    }

    const refresh = async () => {
      this.captchaService.token = null;
      this.captchaService.invalid = true;

      try {
        const token = await captchaApi.execute(this.siteKey, {
          action: "signup",
        });
        if (active) {
          this.captchaService.token = token || null;
          this.captchaService.invalid = !token;
        }
      } catch {
        // Leave verification invalid so the user can retry submission.
      }
    };

    this.captchaService.refreshToken = refresh;
    return () => {
      active = false;
      if (this.captchaService.refreshToken === refresh) {
        this.captchaService.refreshToken = null;
        this.captchaService.reset();
      }
    };
  });

  get scriptUrl() {
    return `https://www.google.com/recaptcha/api.js?onload=${this.callbackName}&render=${this.siteKey}`;
  }

  get callbackName() {
    return "discourseReCaptchaV3Callback";
  }

  get captchaApiName() {
    return "grecaptcha";
  }

  get providerName() {
    return "reCaptcha v3";
  }

  get containerId() {
    return "g-recaptcha-v3";
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
          class="captcha-container re-captcha-v3"
          id={{this.containerId}}
          {{this.registerCaptcha captchaApi=captchaApi}}
        ></div>
      </:content>
      <:error>
        {{#unless @onError}}
          <div class="alert alert-error">
            {{i18n this.captchaErrorKey}}
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
