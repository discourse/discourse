import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { extractError } from "discourse/lib/ajax-error";
import CategoryChooser from "discourse/select-kit/components/category-chooser";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import DSelectCategory from "discourse/ui-kit/select/recipes/categories/d-select-category";
import { i18n } from "discourse-i18n";

export default class ConvertToPublicTopic extends Component {
  @service appEvents;
  @service siteSettings;

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
      class="convert-to-public-topic"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @title={{i18n "topic.make_public.title"}}
    >
      <:body>
        <div class="instructions" id="make-public-category-label">
          {{i18n "topic.make_public.choose_category"}}
        </div>
        {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
        {{#if this.siteSettings.enable_new_select_controls}}
          <DSelectCategory
            class="category-chooser"
            @ariaLabelledBy="make-public-category-label"
            @emit="ids"
            @onChange={{fn (mut this.publicCategoryId)}}
            @permission="create"
            @value={{this.publicCategoryId}}
          />
        {{else}}
          <CategoryChooser
            @onChange={{fn (mut this.publicCategoryId)}}
            @value={{this.publicCategoryId}}
          />
        {{/if}}
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.makePublic}}
          @disabled={{this.saving}}
          @label="composer.modal_ok"
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
