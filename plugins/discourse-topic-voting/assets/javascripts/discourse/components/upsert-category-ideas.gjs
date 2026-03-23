import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import EditCategoryTypeSchemaFields from "discourse/components/edit-category-type-schema-fields";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";

export default class UpsertCategoryIdeas extends Component {
  @service dialog;
  @service toasts;
  @service router;

  get isIdeasCategory() {
    return this.args.category.isType("ideas");
  }

  @action
  removeIdeasCategory() {
    this.dialog.yesNoConfirm({
      message: i18n(
        "topic_voting.category_type_ideas.confirm_remove_ideas_type"
      ),
      didConfirm: async () => {
        this.args.category.set("custom_fields.enable_topic_voting", "false");
        this.args.form.set("custom_fields.enable_topic_voting", "false");
        try {
          await this.args.category.save();
          this.args.category.removeType("ideas");
          this.toasts.success({
            duration: "short",
            data: {
              message: i18n("saved"),
            },
          });
          this.router.transitionTo(
            "editCategory.tabs",
            Category.slugFor(this.args.category),
            "general"
          );
        } catch (err) {
          this.args.category.set("custom_fields.enable_topic_voting", "true");
          popupAjaxError(err);
        }
      },
    });
  }

  <template>
    {{#if this.isIdeasCategory}}
      <EditCategoryTypeSchemaFields
        @category={{@category}}
        @categoryType="ideas"
        @form={{@form}}
      >
        <:beforeSiteSettings>
          {{#if @category.id}}
            <div class="ideas-category--danger-zone">
              <DButton
                class="btn-small ideas-category__remove-type"
                @action={{this.removeIdeasCategory}}
                @icon="link-slash"
                @label="topic_voting.category_type_ideas.remove_ideas_type"
              />
            </div>
          {{/if}}
        </:beforeSiteSettings>
      </EditCategoryTypeSchemaFields>
    {{else}}
      {{i18n "topic_voting.category_type_ideas.not_ideas_type"}}
    {{/if}}
  </template>
}
