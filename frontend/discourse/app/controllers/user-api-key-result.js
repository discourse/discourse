import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import copyText from "discourse/lib/copy-text";
import { i18n } from "discourse-i18n";

export default class UserApiKeyResultController extends Controller {
  @tracked copied = false;

  get buttonLabel() {
    return this.copied
      ? i18n("user_api_key.copied")
      : i18n("user_api_key.copy_key");
  }

  @action
  copy() {
    this.copied = copyText(this.model.payload?.replace(/\s/g, ""));

    if (this.copied) {
      setTimeout(() => (this.copied = false), 2000);
    }
  }
}
