import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class AiThemeTranslationModal extends Component {
  @service siteSettings;
  @service toasts;

  @cached
  get formData() {
    return { override_existing: false };
  }

  get sourceLanguage() {
    return (
      this.siteSettings.available_locales.find(
        (locale) => locale.value === this.args.model.locale
      )?.name ?? this.args.model.locale
    );
  }

  @cached
  get targetLocales() {
    return [
      ...new Set(
        (this.siteSettings.content_localization_supported_locales || "").split(
          "|"
        )
      ),
    ]
      .filter((locale) => locale && locale !== this.args.model.locale)
      .map((value) => ({
        value,
        name:
          this.siteSettings.available_locales.find(
            (locale) => locale.value === value
          )?.name ?? value,
      }));
  }

  @action
  async translate(data) {
    if (!this.targetLocales.length) {
      return;
    }
    try {
      await ajax("/admin/plugins/discourse-ai/ai-theme-translations", {
        type: "POST",
        data: {
          theme_id: this.args.model.theme.id,
          locale: this.args.model.locale,
          target_locales: this.targetLocales.map((locale) => locale.value),
          override_existing: data.override_existing,
        },
      });
      this.args.closeModal();
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n(
            "discourse_ai.translations.theme_translations.translate.queued"
          ),
        },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <DModal
      class="ai-theme-translation-modal"
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      @title={{i18n
        "discourse_ai.translations.theme_translations.translate.label"
      }}
    >
      <:body>
        <p>{{i18n
            "discourse_ai.translations.theme_translations.translate.confirm"
            language=this.sourceLanguage
          }}</p>
        {{#if this.targetLocales.length}}
          <ul class="ai-theme-translation-modal__languages">
            {{#each this.targetLocales as |locale|}}
              <li>{{locale.name}}</li>
            {{/each}}
          </ul>
          <Form @data={{this.formData}} @onSubmit={{this.translate}} as |form|>
            <form.Field
              @format="full"
              @name="override_existing"
              @title={{i18n
                "discourse_ai.translations.theme_translations.translate.override_existing"
              }}
              @type="checkbox"
              as |field|
            >
              <field.Control />
            </form.Field>
            <form.Actions>
              <form.Submit
                @label="discourse_ai.translations.theme_translations.translate.label"
              />
            </form.Actions>
          </Form>
        {{else}}
          <p>{{i18n
              "discourse_ai.translations.theme_translations.translate.no_targets"
            }}</p>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
