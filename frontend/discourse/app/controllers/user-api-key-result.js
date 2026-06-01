import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class UserApiKeyResultController extends Controller {
  @tracked copied = false;

  get buttonLabel() {
    return this.copied
      ? i18n("user_api_key.copied")
      : i18n("user_api_key.copy_key");
  }

  @action
  async copy() {
    try {
      await clipboardCopy(this.model.payload?.replace(/\s/g, ""));
      this.copied = true;
    } catch {
      this.copied = false;
    }

    if (this.copied) {
      setTimeout(() => (this.copied = false), 2000);
    }
  }
}
