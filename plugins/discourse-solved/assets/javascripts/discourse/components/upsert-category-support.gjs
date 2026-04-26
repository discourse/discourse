import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import EditCategoryTypeSchemaFields from "discourse/components/edit-category-type-schema-fields";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";

export default class UpsertCategorySupport extends Component {
  @service dialog;
  @service toasts;
  @service router;

  get isSupportCategory() {
    return this.args.category.isType("support");
  }

  @action
  removeSupportCategory() {
    this.dialog.yesNoConfirm({
      message: i18n("solved.category_type_support.confirm_remove_support_type"),
      didConfirm: async () => {
        this.args.category.set(
          "custom_fields.enable_accepted_answers",
          "false"
        );
        this.args.form.set("custom_fields.enable_accepted_answers", "false");
        try {
          await this.args.category.save();
          this.args.category.removeType("support");
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
          this.args.category.set(
            "custom_fields.enable_accepted_answers",
            "true"
          );
          popupAjaxError(err);
        }
      },
    });
  }

  <template>
    {{#if this.isSupportCategory}}
      <EditCategoryTypeSchemaFields
        @category={{@category}}
        @categoryType="support"
        @form={{@form}}
      >
        <:beforeSiteSettings>
          <div class="support-category--danger-zone">
            <DButton
              class="btn-small support-category__remove-type"
              @action={{this.removeSupportCategory}}
              @icon="link-slash"
              @label="solved.category_type_support.remove_support_type"
            />
          </div>
        </:beforeSiteSettings>
      </EditCategoryTypeSchemaFields>
    {{else}}
      {{i18n "solved.category_type_support.not_support_type"}}
    {{/if}}
  </template>
}
