import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { extractError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import CategoryChooser from "select-kit/components/category-chooser";

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

  <template>
    <DModal
      @title={{i18n "topic.make_public.title"}}
      @closeModal={{@closeModal}}
      class="convert-to-public-topic"
      @flash={{this.flash}}
    >
      <:body>
        <div class="instructions">
          {{i18n "topic.make_public.choose_category"}}
        </div>
        <CategoryChooser
          @value={{this.publicCategoryId}}
          @onChange={{fn (mut this.publicCategoryId)}}
        />
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.makePublic}}
          @label="composer.modal_ok"
          @disabled={{this.saving}}
        />
        <DButton
          class="btn-flat d-modal-cancel"
          @action={{@closeModal}}
          @label="cancel"
        />
      </:footer>
    </DModal>
  </template>
}
