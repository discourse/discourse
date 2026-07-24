import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const CONVERSION_COMPLETED_CUSTOM_FIELD = "nested_replies_conversion_completed";

export default class NestedRepliesSettingsUpsert extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.nested_replies_enabled;
  }

  @service a11y;
  @service dialog;

  @tracked completed = false;
  @tracked converting = false;

  get category() {
    return this.args.outletArgs.category;
  }

  get enabled() {
    const value =
      this.args.outletArgs.transientData?.category_setting
        ?.nested_replies_default;
    return !!value;
  }

  get persistedEnabled() {
    return !!this.category?.category_setting?.nested_replies_default;
  }

  get persistedCompleted() {
    const value =
      this.category?.custom_fields?.[CONVERSION_COMPLETED_CUSTOM_FIELD];
    return value === true || value === "true" || value === "t" || value === "1";
  }

  get conversionCompleted() {
    return (
      this.enabled &&
      this.persistedEnabled &&
      (this.completed || this.persistedCompleted)
    );
  }

  get showSaveFirstMessage() {
    return this.category?.id && this.enabled && !this.persistedEnabled;
  }

  get canConvertExistingTopics() {
    return (
      this.enabled &&
      this.category?.id &&
      this.persistedEnabled &&
      !this.conversionCompleted
    );
  }

  @action
  async onToggle(_, { set, name }) {
    await set(name, !this.enabled);
  }

  @action
  async convertExistingTopics() {
    const confirmed = await this.dialog.yesNoConfirm({
      message: i18n(
        "nested_replies.category_settings.convert_existing_confirm"
      ),
    });

    if (!confirmed) {
      return;
    }

    this.converting = true;

    try {
      const result = await ajax(
        `/categories/${this.category.id}/convert_nested_replies`,
        { type: "POST" }
      );

      this.completed = result.nested_replies_conversion_completed;
      this.category.custom_fields ??= {};
      this.category.custom_fields[CONVERSION_COMPLETED_CUSTOM_FIELD] = true;
      this.a11y.announce(
        i18n("nested_replies.category_settings.convert_existing_complete"),
        "polite"
      );
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.converting = false;
    }
  }

  <template>
    {{#let @outletArgs.form as |form|}}
      <form.Section
        @title={{i18n "nested_replies.nested_view"}}
        class="category-custom-settings-outlet nested-replies-category-settings"
      >
        <form.Object @name="category_setting" as |categorySetting|>
          <categorySetting.Field
            @type="checkbox"
            @name="nested_replies_default"
            @title={{i18n
              "nested_replies.category_settings.default_nested_view"
            }}
            @onSet={{this.onToggle}}
            as |field|
          >
            <field.Control />
          </categorySetting.Field>
        </form.Object>

        {{#if this.showSaveFirstMessage}}
          <form.Alert
            @type="info"
            class="nested-replies-category-settings__notice"
          >
            {{i18n "nested_replies.category_settings.save_first"}}
          </form.Alert>
        {{else if this.conversionCompleted}}
          <form.Alert
            @type="success"
            class="nested-replies-category-settings__notice"
          >
            {{i18n
              "nested_replies.category_settings.convert_existing_complete"
            }}
          </form.Alert>
        {{else if this.canConvertExistingTopics}}
          <form.Alert
            @type="info"
            class="nested-replies-category-settings__notice"
          >
            {{i18n
              "nested_replies.category_settings.convert_existing_description"
            }}
          </form.Alert>

          <DButton
            @action={{this.convertExistingTopics}}
            @disabled={{this.converting}}
            @isLoading={{this.converting}}
            @label="nested_replies.category_settings.convert_existing"
            class="btn-default nested-replies-category-settings__convert-button"
          />
        {{/if}}
      </form.Section>
    {{/let}}
  </template>
}
