import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import I18n from "I18n";

export default class ConvertToPublicTopic extends Component {
  @service appEvents;

  @tracked publicCategoryId;
  @tracked saving = false;
  @tracked flash;

  @action
  async makePublic() {
    try {
      this.saving = true;
      await this.args.model.topic.convertTopic("public", {
        categoryId: this.publicCategoryId,
      });
      this.args.model.topic.set("archetype", "regular");
      this.args.model.topic.set("category_id", this.publicCategoryId);
      this.appEvents.trigger("header:show-topic", this.args.model.topic);
      this.saving = false;
      this.args.closeModal();
    } catch (e) {
      this.flash = I18n.t("generic_error");
      this.saving = false;
    }
  }
}
