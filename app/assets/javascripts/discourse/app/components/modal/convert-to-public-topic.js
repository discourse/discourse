import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { extractError } from "discourse/lib/ajax-error";

export default class ConvertToPublicTopic extends Component {
  @service appEvents;

  @tracked publicCategoryId;
  @tracked saving = false;
  @tracked flash;

  @action
  async makePublic() {
    const { topic } = this.args.model;

    try {
      this.saving = true;
      await topic.convertTopic("public", { categoryId: this.publicCategoryId });
      topic.set("archetype", "regular");
      topic.set("category_id", this.publicCategoryId);
      this.appEvents.trigger("header:show-topic", topic);
      this.args.closeModal();
    } catch (e) {
      this.flash = extractError(e);
    } finally {
      this.saving = false;
    }
  }
}
