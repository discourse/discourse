import { modifier as modifierFn } from "ember-modifier";
import DAsyncContent from "discourse/ui-kit/d-async-content";
import DInputTip from "discourse/ui-kit/d-input-tip";
import { i18n } from "discourse-i18n";
import BaseCaptcha from "./base-captcha";

export default class ReCaptchaV3 extends BaseCaptcha {
  fetchToken = modifierFn((_element, _args, { captchaApi }) => {
    const fetchToken = () =>
      captchaApi
        .execute(this.siteKey, { action: "signup" })
        .then((response) => {
          // `grecaptcha.execute` can resolve with an empty result when called
          // again shortly after a previous call, so only treat a real token as
          // success and otherwise keep any token we already have.
          if (!response) {
            this.captchaService.invalid = true;
            return;
          }
          this.captchaService.token = response;
          this.captchaService.invalid = false;
        })
        .catch(() => {
          this.captchaService.invalid = true;
        });

    const refresh = () => {
      // ReCAPTCHA v3 tokens are single-use and valid for a short window, but
      // re-executing immediately returns an empty result. Reuse the token we
      // already captured unless there is none to submit.
      if (this.captchaService.token) {
        this.captchaService.invalid = false;
        return;
      }
      return fetchToken();
    };

    this.captchaService.refreshToken = refresh;
    // A token may already be present if the captcha step was re-rendered (e.g.
    // when going back and forward through the signup steps). Reusing it avoids
    // the empty response that `grecaptcha.execute` returns on rapid re-calls.
    if (!this.captchaService.token) {
      fetchToken();
    } else {
      this.captchaService.invalid = false;
    }
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
          {{this.fetchToken captchaApi=captchaApi}}
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
