import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DEditorOriginalTranslationPreview from "discourse/components/d-editor-original-translation-preview";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Composer from "discourse/models/composer";
import PostLocalization from "discourse/models/post-localization";
import TopicLocalization from "discourse/models/topic-localization";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class PostTranslationsModal extends Component {
  @service composer;
  @service dialog;
  @service languageNameLookup;
  @service siteSettings;
  @service toasts;

  @tracked postLocalizations = null;
  @tracked loading = false;
  @tracked savingPostLocale = false;
  @tracked savingTopicLocale = false;
  @tracked savedPostLocale;
  @tracked savedTopicLocale;

  constructor() {
    super(...arguments);
    this.savedPostLocale = this.post.locale ?? null;
    this.savedTopicLocale = this.topic?.locale ?? null;
    this.postLocaleFormData = { locale: this.savedPostLocale };
    this.topicLocaleFormData = { locale: this.savedTopicLocale };
    this.loadPostLocalizations();
  }

  get post() {
    return this.args.model.post;
  }

  get topic() {
    return this.post.topic;
  }

  get localeOptions() {
    const locales = [...this.siteSettings.available_locales];
    const availableValues = new Set(locales.map(({ value }) => value));

    [this.post.locale, this.topic?.locale].forEach((locale) => {
      if (locale && !availableValues.has(locale)) {
        locales.push({ value: locale });
      }
    });

    return locales.map(({ value }) => ({
      value,
      label: this.localeLabel(value),
    }));
  }

  localeLabel(locale) {
    return `${this.languageNameLookup.getLanguageName(locale)} (${locale})`;
  }

  async loadPostLocalizations() {
    this.loading = true;

    try {
      const { post_localizations } = await PostLocalization.find(
        this.args.model.post.id
      );

      this.postLocalizations = post_localizations.map((localization) => ({
        ...localization,
        languageName: this.localeLabel(localization.locale),
      }));
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.loading = false;
    }
  }

  get canLocalizePost() {
    return this.post.can_localize_post;
  }

  @action
  async savePostLocale(selectedLocale, commitField) {
    this.savingPostLocale = true;

    try {
      const { locale } = await PostLocalization.updateLocale(
        this.post.id,
        selectedLocale
      );
      this.post.set("locale", locale);
      this.savedPostLocale = locale;
      commitField("locale");
      this.toasts.success({
        data: {
          message: i18n("post.localizations.modal.post_language_updated"),
        },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.savingPostLocale = false;
    }
  }

  @action
  async saveTopicLocale(selectedLocale, commitField) {
    this.savingTopicLocale = true;

    try {
      const { locale } = await TopicLocalization.updateLocale(
        this.topic.id,
        selectedLocale
      );
      this.topic.set("locale", locale);
      this.savedTopicLocale = locale;
      commitField("locale");
      this.toasts.success({
        data: {
          message: i18n("post.localizations.modal.topic_language_updated"),
        },
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.savingTopicLocale = false;
    }
  }

  @action
  async discardLocale(set, commitField, savedLocale) {
    await set("locale", savedLocale);
    commitField("locale");
  }

  @action
  async editLocalization(locale) {
    if (!this.canLocalizePost) {
      return;
    }

    this.args.closeModal();

    const originalLocale = this.post.locale;

    const { raw } = await ajax(`/posts/${this.post.id}.json`);

    const composerOpts = {
      action: Composer.ADD_TRANSLATION,
      draftKey: "translation",
      warningsDisabled: true,
      hijackPreview: {
        component: DEditorOriginalTranslationPreview,
        model: {
          postLocale: originalLocale,
          rawPost: raw,
          translationText: () => this.composer.model?.reply,
        },
      },
      post: this.post,
      selectedTranslationLocale: locale.locale,
    };

    await this.composer.open(composerOpts);
  }

  @action
  async deleteLocalization(locale) {
    if (!this.canLocalizePost) {
      return;
    }

    try {
      await PostLocalization.destroy(this.post.id, locale);

      if (this.post.firstPost) {
        await TopicLocalization.destroy(this.post.topic_id, locale);
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      window.location.reload();
    }
  }

  @action
  delete(locale) {
    return this.dialog.yesNoConfirm({
      message: i18n("post.localizations.modal.confirm_delete", {
        languageCode: locale,
      }),
      didConfirm: () => {
        return this.deleteLocalization(locale);
      },
    });
  }

  <template>
    <DModal
      @title={{i18n "post.localizations.modal.title"}}
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      class="post-translations-modal"
    >
      <:body>
        <DConditionalLoadingSpinner @size="large" @condition={{this.loading}} />

        <div class="post-translations-modal__language-settings">
          {{#if this.post.firstPost}}
            <Form
              @data={{this.topicLocaleFormData}}
              class="post-translations-modal__language-form post-translations-modal__topic-language"
              as |form topicData|
            >
              <form.Field
                @name="locale"
                @title={{i18n "post.localizations.modal.topic_language"}}
                @type="select"
                @format="full"
                @showOptional={{false}}
                @disabled={{this.savingTopicLocale}}
                as |field|
              >
                <div class="post-translations-modal__language-control">
                  <field.Control
                    @includeNone={{true}}
                    @nonePlaceholder={{i18n
                      "post.localizations.post_language_selector.none"
                    }}
                    as |select|
                  >
                    {{#each this.localeOptions as |locale|}}
                      <select.Option @value={{locale.value}}>
                        {{locale.label}}
                      </select.Option>
                    {{/each}}
                  </field.Control>
                  <div
                    class={{dConcatClass
                      "post-translations-modal__language-actions"
                      (if
                        (eq topicData.locale this.savedTopicLocale) "is-hidden"
                      )
                    }}
                  >
                    <form.Button
                      @action={{fn
                        this.saveTopicLocale
                        topicData.locale
                        form.commitField
                      }}
                      @icon="check"
                      @isLoading={{this.savingTopicLocale}}
                      @disabled={{this.savingTopicLocale}}
                      @title="post.localizations.modal.save_topic_language"
                      @ariaLabel="post.localizations.modal.save_topic_language"
                      class="btn-primary --save"
                    />
                    <form.Button
                      @action={{fn
                        this.discardLocale
                        form.set
                        form.commitField
                        this.savedTopicLocale
                      }}
                      @icon="xmark"
                      @disabled={{this.savingTopicLocale}}
                      @title="post.localizations.modal.discard_language_change"
                      @ariaLabel="post.localizations.modal.discard_language_change"
                      class="btn-default --discard"
                    />
                  </div>
                </div>
              </form.Field>
            </Form>
          {{/if}}

          <Form
            @data={{this.postLocaleFormData}}
            class="post-translations-modal__language-form post-translations-modal__post-language"
            as |form postData|
          >
            <form.Field
              @name="locale"
              @title={{i18n "post.localizations.modal.post_language"}}
              @type="select"
              @format="full"
              @helpText={{i18n "post.localizations.modal.language_notice"}}
              @showOptional={{false}}
              @disabled={{this.savingPostLocale}}
              as |field|
            >
              <div class="post-translations-modal__language-control">
                <field.Control
                  @includeNone={{true}}
                  @nonePlaceholder={{i18n
                    "post.localizations.post_language_selector.none"
                  }}
                  as |select|
                >
                  {{#each this.localeOptions as |locale|}}
                    <select.Option @value={{locale.value}}>
                      {{locale.label}}
                    </select.Option>
                  {{/each}}
                </field.Control>
                <div
                  class={{dConcatClass
                    "post-translations-modal__language-actions"
                    (if (eq postData.locale this.savedPostLocale) "is-hidden")
                  }}
                >
                  <form.Button
                    @action={{fn
                      this.savePostLocale
                      postData.locale
                      form.commitField
                    }}
                    @icon="check"
                    @isLoading={{this.savingPostLocale}}
                    @disabled={{this.savingPostLocale}}
                    @title="post.localizations.modal.save_post_language"
                    @ariaLabel="post.localizations.modal.save_post_language"
                    class="btn-primary --save"
                  />
                  <form.Button
                    @action={{fn
                      this.discardLocale
                      form.set
                      form.commitField
                      this.savedPostLocale
                    }}
                    @icon="xmark"
                    @disabled={{this.savingPostLocale}}
                    @title="post.localizations.modal.discard_language_change"
                    @ariaLabel="post.localizations.modal.discard_language_change"
                    class="btn-default --discard"
                  />
                </div>
              </div>
            </form.Field>
          </Form>
        </div>

        {{#if this.postLocalizations}}
          <table>
            <thead>
              <tr>
                <th>{{i18n "post.localizations.table.locale"}}</th>
                <th colspan="2">{{i18n "post.localizations.table.actions"}}</th>
              </tr>
            </thead>
            <tbody>
              {{#each this.postLocalizations as |localization|}}
                <tr>
                  <td
                    class="post-translations-modal__locale"
                  >{{localization.languageName}}</td>
                  <td class="post-translations-modal__edit-action">
                    {{#if this.canLocalizePost}}
                      <DButton
                        class="btn-transparent --primary"
                        @icon="pencil"
                        @label="post.localizations.table.edit"
                        @action={{fn this.editLocalization localization}}
                      />
                    {{/if}}
                  </td>
                  <td class="post-translations-modal__delete-action">
                    {{#if this.canLocalizePost}}
                      <DButton
                        class="btn-transparent --danger"
                        @icon="trash-can"
                        @label="post.localizations.table.delete"
                        @action={{fn this.delete localization.locale}}
                      />
                    {{/if}}
                  </td>
                </tr>
              {{/each}}
            </tbody>
          </table>
        {{/if}}
      </:body>
    </DModal>
  </template>
}
