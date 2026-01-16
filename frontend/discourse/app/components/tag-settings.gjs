import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageHeader from "discourse/components/d-page-header";
import Form from "discourse/components/form";
import HorizontalOverflowNav from "discourse/components/horizontal-overflow-nav";
import AddSynonymsConfirmation from "discourse/components/tag-settings/add-synonyms-confirmation";
import TagSettingsLocalizations from "discourse/components/tag-settings/localizations";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import TagDropdown from "discourse/select-kit/components/tag-dropdown";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class TagSettings extends Component {
  @service router;
  @service dialog;
  @service toasts;
  @service siteSettings;
  @service store;

  @tracked form = null;
  @tracked tags = [];

  constructor() {
    super(...arguments);
    this.loadTags();
  }

  async loadTags() {
    try {
      const tags = await this.store.findAll("tag");
      this.tags = tags.content.map((tag) => ({
        id: tag.id,
        name: tag.name,
      }));
    } catch {}
  }

  get tagNames() {
    return this.tags.map((t) => t.name);
  }

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

  get hasTagGroups() {
    return this.args.tag.tag_group_names?.length > 0;
  }

  get tagGroupsInfoPrefix() {
    const count = this.args.tag.tag_group_names?.length || 0;
    if (count === 1) {
      return i18n("tagging.tag_groups_info_prefix.one");
    }
    return i18n("tagging.tag_groups_info_prefix.other");
  }

  get tagGroupNames() {
    return this.args.tag.tag_group_names?.join(", ");
  }

  get hasCategories() {
    return this.args.tag.categories?.length > 0;
  }

  get isCategoryRestricted() {
    return this.args.tag.category_restricted;
  }

  get descriptionHtml() {
    const parts = [];

    if (this.hasTagGroups) {
      const prefix =
        this.args.tag.tag_group_names.length === 1
          ? i18n("tagging.tag_groups_info_prefix.one")
          : i18n("tagging.tag_groups_info_prefix.other");
      const groups = (this.args.tag.tag_groups || [])
        .map((tg) => `<a href="/tag_groups/${tg.id}">${tg.name}</a>`)
        .join(", ");
      parts.push(`${prefix}${groups}.`);
    }

    if (this.hasCategories) {
      const categoriesHtml = this.args.tag.categories
        .map(
          (cat) =>
            `<a href="/c/${cat.slug}/${cat.id}" class="badge-category">${cat.name}</a>`
        )
        .join(" ");
      parts.push(`${i18n("tagging.restricted_to")} ${categoriesHtml}.`);
    } else if (this.isCategoryRestricted) {
      parts.push(i18n("tagging.category_restricted"));
    }

    return parts.join(" ");
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
      const result = await ajax(`/tag/${tag.id}/settings.json`, {
        type: "PUT",
        contentType: "application/json",
        data: JSON.stringify({ tag_settings: data }),
      });

      if (result.tag_settings) {
        this.args.tag.setProperties(result.tag_settings);

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

  @action
  handleSynonymChange(selectedTags) {
    const originalSynonyms = this.args.tag.synonyms || [];
    const originalIds = originalSynonyms.map((s) => s.id);
    const selectedIds = selectedTags.map((t) => t.id);

    const removed = originalSynonyms.filter((s) => !selectedIds.includes(s.id));
    const removedIds = removed.map((s) => s.id);

    const newSynonyms = selectedTags.filter((t) => !originalIds.includes(t.id));

    this.form?.set("synonyms", selectedTags);
    this.form?.set("removed_synonym_ids", removedIds);
    this.form?.set("new_synonyms", newSynonyms);
  }

  get blockedTags() {
    return [this.args.tag?.name].filter(Boolean);
  }

  <template>
    <div class="tag-settings">
      <DPageHeader
        @descriptionLabel={{this.descriptionHtml}}
        @hideTabs={{true}}
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @path="/tags" @label={{i18n "tagging.tags"}} />
          <DBreadcrumbsItem
            @path="/tag/{{@tag.slug}}/{{@tag.id}}"
            @label={{@tag.name}}
          />
          <DBreadcrumbsItem
            @path="/tag/{{@tag.slug}}/{{@tag.id}}/edit/general"
            @label={{i18n "edit"}}
          />
          {{#if this.showLocalizationsTab}}
            <DBreadcrumbsItem
              @path="/tag/{{@tag.slug}}/{{@tag.id}}/edit/{{@selectedTab}}"
              @label={{i18n (concat "tagging.settings." @selectedTab)}}
            />
          {{/if}}
        </:breadcrumbs>
        <:title>
          <span class="tag-settings-title__label">{{i18n
              "tagging.settings.edit_tag_prefix"
            }}</span>
          <span class="tag-settings-title__dropdown">
            <TagDropdown
              @tags={{this.tags}}
              @value={{@tag.name}}
              aria-label={{i18n "tagging.settings.select_tag"}}
            />
          </span>
        </:title>
        <:actions as |actions|>
          {{#if @tag.can_admin}}
            <actions.Danger
              @action={{this.deleteTag}}
              @icon="trash-can"
              @label="tagging.settings.delete"
            />
          {{/if}}
        </:actions>
      </DPageHeader>

      {{#if this.showLocalizationsTab}}
        <div class="d-nav-submenu">
          <HorizontalOverflowNav class="d-nav-submenu__tabs">
            <li>
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
            <li>
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
          </HorizontalOverflowNav>
        </div>
      {{/if}}

      <Form
        @data={{this.formData}}
        @onSubmit={{this.save}}
        @onRegisterApi={{this.registerForm}}
        class="tag-settings__form"
        as |form transientData|
      >
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
            @validation="length:0,1000"
            as |field|
          >
            <field.Textarea @height={{80}} />
          </form.Field>

          <form.Field
            @name="synonyms"
            @title={{i18n "tagging.synonyms"}}
            @description={{i18n
              "tagging.settings.synonyms_subtitle"
              name=@tag.name
            }}
            @format="large"
            as |field|
          >
            <field.Custom>
              <MiniTagChooser
                @value={{transientData.synonyms}}
                @onChange={{this.handleSynonymChange}}
                @options={{hash
                  everyTag=true
                  blockedTags=this.blockedTags
                  filterPlaceholder="tagging.settings.add_synonym_placeholder"
                  maximum=200
                }}
              />
            </field.Custom>
          </form.Field>
        {{else if (eq @selectedTab "localizations")}}
          <TagSettingsLocalizations
            @localizations={{transientData.localizations}}
            @tagId={{@tag.id}}
            @form={{form}}
          />
        {{/if}}

        <form.Actions>
          <form.Submit @label="tagging.settings.save" id="save-tag" />
        </form.Actions>
      </Form>
    </div>
  </template>
}
