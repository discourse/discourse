import { tracked } from "@glimmer/tracking";
import EmberObject from "@ember/object";
import Service from "@ember/service";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { i18n } from "discourse-i18n";

@disableImplicitInjections
export default class CaptchaService extends Service {
  @tracked invalid = true;
  @tracked submitted = false;
  @tracked token = null;
  widgetId = null;
  captcha = null;

  get submitFailed() {
    return this.submitted && this.invalid;
  }

  get inputValidation() {
    return EmberObject.create({
      failed: this.invalid,
      reason: i18n("discourse_captcha.missing_token"),
    });
  }

  registerWidget(captcha, id) {
    this.captcha = captcha;
    this.widgetId = id;
  }

  reset() {
    this.invalid = true;
    this.submitted = false;
    this.token = null;
    this.captcha.reset(this.widgetId);
  }
}
