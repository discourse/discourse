import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import Form from "discourse/components/form";
import AddSynonymsConfirmation from "discourse/components/tag-settings/add-synonyms-confirmation";
import TagSettingsLocalizations from "discourse/components/tag-settings/localizations";
import TagSettingsSynonyms from "discourse/components/tag-settings/synonyms";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class TagSettings extends Component {
  @service router;
  @service dialog;
  @service toasts;
  @service siteSettings;

  @tracked form = null;
  @tracked saved = false;

  get formData() {
    return {
      name: this.args.tag.name,
      slug: this.args.tag.slug,
      description: this.args.tag.description || "",
      synonyms: this.args.tag.synonyms || [],
      new_synonyms: [],
      removed_synonym_ids: [],
      localizations: this.args.tag.localizations || [],
    };
  }

  get showLocalizationsTab() {
    return this.siteSettings.content_localization_enabled;
  }

  @action
  async save(data) {
    const newSynonyms = data.new_synonyms || [];

    if (newSynonyms.length > 0) {
      this.dialog.confirm({
        bodyComponent: AddSynonymsConfirmation,
        bodyComponentModel: {
          count: newSynonyms.length,
          tagName: data.name,
          synonymNames: newSynonyms.map((t) => t.name).join(", "),
        },
        didConfirm: () => this.#performSave(data),
      });
    } else {
      await this.#performSave(data);
    }
  }

  async #performSave(data) {
    const tag = this.args.tag;

    try {
      const result = await ajax(`/tag/${tag.slug}/${tag.id}/settings.json`, {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({ tag_settings: data }),
      });

      this.saved = true;

      if (result.tag_settings) {
        this.args.tag.setProperties(result.tag_settings);

        this.form?.set("synonyms", result.tag_settings.synonyms || []);
        this.form?.set("new_synonyms", []);
        this.form?.set("removed_synonym_ids", []);

        if (result.tag_settings.slug !== this.args.parentParams.tag_slug) {
          this.router.replaceWith(
            "tag.edit.tab",
            result.tag_settings.slug,
            result.tag_settings.id,
            this.args.selectedTab
          );
        }
      }

      this.toasts.success({
        duration: "short",
        data: { message: i18n("tagging.settings.saved") },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  registerForm(form) {
    this.form = form;
  }

  @action
  onDirtyCheck() {
    return !this.saved;
  }

  @action
  deleteTag() {
    const tag = this.args.tag;
    const topicCount = tag.topic_count || 0;

    const message = topicCount
      ? i18n("tagging.delete_confirm", { count: topicCount })
      : i18n("tagging.delete_confirm_no_topics");

    this.dialog.deleteConfirm({
      message,
      didConfirm: async () => {
        try {
          await ajax(`/tag/${tag.slug}/${tag.id}.json`, { type: "DELETE" });
          this.router.transitionTo("tags.index");
        } catch (error) {
          popupAjaxError(error);
        }
      },
    });
  }

  <template>
    <div class="tag-settings">
      <div class="tag-settings__header">
        <h2>{{i18n "tagging.settings.edit_title" name=@tag.name}}</h2>
        <DButton
          @route="tag.show"
          @routeModels={{array @tag.slug @tag.id}}
          @label="tagging.settings.back"
          @icon="caret-left"
          class="tag-settings__back-btn"
        />
      </div>

      <div class="tag-settings__nav">
        <ul class="nav nav-stacked">
          <li class={{if (eq @selectedTab "general") "active"}}>
            <LinkTo
              @route="tag.edit.tab"
              @models={{array
                @parentParams.tag_slug
                @parentParams.tag_id
                "general"
              }}
            >
              {{i18n "tagging.settings.general"}}
            </LinkTo>
          </li>
          {{#if this.showLocalizationsTab}}
            <li class={{if (eq @selectedTab "localizations") "active"}}>
              <LinkTo
                @route="tag.edit.tab"
                @models={{array
                  @parentParams.tag_slug
                  @parentParams.tag_id
                  "localizations"
                }}
              >
                {{i18n "tagging.settings.localizations"}}
              </LinkTo>
            </li>
          {{/if}}
        </ul>
      </div>

      <Form
        @data={{this.formData}}
        @onSubmit={{this.save}}
        @onRegisterApi={{this.registerForm}}
        @onDirtyCheck={{this.onDirtyCheck}}
        class="tag-settings__form"
        as |form transientData|
      >
        <form.Section class="tag-settings__content">
          {{#if (eq @selectedTab "general")}}
            <form.Field
              @name="name"
              @title={{i18n "tagging.settings.name"}}
              @format="large"
              @validation="required"
              as |field|
            >
              <field.Input
                placeholder={{i18n "tagging.settings.name_placeholder"}}
                @maxlength={{this.siteSettings.max_tag_length}}
                class="tag-name-input"
              />
            </form.Field>

            <form.Field
              @name="slug"
              @title={{i18n "tagging.settings.slug"}}
              @format="large"
              as |field|
            >
              <field.Input
                placeholder={{i18n "tagging.settings.slug_placeholder"}}
              />
            </form.Field>

            <form.Field
              @name="description"
              @title={{i18n "tagging.description"}}
              @format="large"
              as |field|
            >
              <field.Textarea @height={{80}} />
            </form.Field>

            <form.Section @title={{i18n "tagging.synonyms"}}>
              <TagSettingsSynonyms
                @synonyms={{transientData.synonyms}}
                @newSynonyms={{transientData.new_synonyms}}
                @removedSynonymIds={{transientData.removed_synonym_ids}}
                @tag={{@tag}}
                @form={{form}}
              />
            </form.Section>
          {{else if (eq @selectedTab "localizations")}}
            <TagSettingsLocalizations
              @localizations={{transientData.localizations}}
              @tagId={{@tag.id}}
              @form={{form}}
            />
          {{/if}}
        </form.Section>

        <form.Actions class="tag-settings__footer">
          <form.Submit @label="tagging.settings.save" id="save-tag" />

          {{#if @tag.can_admin}}
            <form.Button
              @action={{this.deleteTag}}
              @icon="trash-can"
              @label="tagging.settings.delete"
              class="btn-danger tag-settings__delete-btn"
            />
          {{/if}}
        </form.Actions>
      </Form>
    </div>
  </template>
}
