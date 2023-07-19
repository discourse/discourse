import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { fixQuotes } from "discourse/components/quote-button";
import { translateModKey } from "discourse/lib/utilities";
import I18n from "I18n";

export default class FastEdit extends Component {
  @tracked value = this.args.initialValue;
  @tracked isSaving = false;

  buttonTitle = I18n.t("composer.title", {
    modifier: translateModKey("Meta+"),
  });

  @action
  updateValue(event) {
    this.value = event.target.value;
  }

  @action
  async save() {
    this.isSaving = true;

    try {
      const result = await ajax(`/posts/${this.args.post.id}`);
      const newRaw = result.raw.replace(
        fixQuotes(this.args.initialValue),
        fixQuotes(this.value)
      );

      await this.args.post.save({ raw: newRaw });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isSaving = false;
      this.args.afterSave?.();
    }
  }
}
