import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { array, concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { LinkTo } from "@ember/routing";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import AddSynonymsConfirmation from "discourse/components/tag-settings/add-synonyms-confirmation";
import TagSettingsLocalizations from "discourse/components/tag-settings/localizations";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import { slugify } from "discourse/lib/utilities";
import MiniTagChooser from "discourse/select-kit/components/mini-tag-chooser";
import TagDropdown from "discourse/select-kit/components/tag-dropdown";
import { eq } from "discourse/truth-helpers";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DHorizontalOverflowNav from "discourse/ui-kit/d-horizontal-overflow-nav";
import DPageHeader from "discourse/ui-kit/d-page-header";
import { categoryBadgeHTML } from "discourse/ui-kit/helpers/d-category-link";
import { i18n } from "discourse-i18n";

export default class TagSettings extends Component {
  @service router;
  @service dialog;
  @service toasts;
  @service siteSettings;
  @service store;
  @service appEvents;

  @tracked form = null;
  @tracked tags = [];

  constructor() {
    super(...arguments);
    this.loadTags();
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

  // safe to build HTML here - tag names have <> stripped by TAGS_FILTER_REGEXP,
  // descriptions are sanitized in the backend
  get descriptionHtml() {
    const parts = [];

    if (this.hasTagGroups) {
      const prefix =
        this.args.tag.tag_group_names.length === 1
          ? i18n("tagging.tag_groups_info_prefix.one")
          : i18n("tagging.tag_groups_info_prefix.other");
      const groups = (this.args.tag.tag_groups || [])
        .map(
          (tg) => `<a href="${getURL(`/tag_groups/${tg.id}`)}">${tg.name}</a>`
        )
        .join(", ");
      parts.push(`${prefix}${groups}.`);
    }

    if (this.hasCategories) {
      parts.push(
        i18n("tagging.category_restrictions", {
          count: this.args.tag.categories.length,
          categories: this.args.tag.categories
            .map((cat) => categoryBadgeHTML(cat))
            .join(" "),
        })
      );
    } else if (this.isCategoryRestricted) {
      parts.push(i18n("tagging.category_restricted"));
    }

    return parts.join(" ");
  }

  get blockedTags() {
    return [this.args.tag?.name].filter(Boolean);
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
          await ajax(`/tag/${tag.id}.json`, { type: "DELETE" });
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

  @action
  validateSlug(name, slug, { addError }) {
    if (slug?.trim() && slug !== slugify(slug)) {
      addError(name, {
        title: i18n("tagging.settings.slug"),
        message: i18n("tagging.settings.invalid_slug"),
      });
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

        this.appEvents.trigger("tag-info:updated", result.tag_settings.id);
      }

      this.toasts.success({
        duration: "short",
        data: { message: i18n("tagging.settings.saved") },
      });
    } catch (error) {
      popupAjaxError(error);
    }
  }

  <template>
    <div class="tag-settings">
      <DPageHeader
        @descriptionLabel={{this.descriptionHtml}}
        @hideTabs={{true}}
      >
        <:breadcrumbs>
          <DBreadcrumbsItem @label={{i18n "tagging.tags"}} @path="/tags" />
          <DBreadcrumbsItem
            @label={{@tag.name}}
            @path="/tag/{{@tag.slug}}/{{@tag.id}}"
          />
          <DBreadcrumbsItem
            @label={{i18n "edit"}}
            @path="/tag/{{@tag.slug}}/{{@tag.id}}/edit/general"
          />
          {{#if this.showLocalizationsTab}}
            <DBreadcrumbsItem
              @label={{i18n (concat "tagging.settings." @selectedTab)}}
              @path="/tag/{{@tag.slug}}/{{@tag.id}}/edit/{{@selectedTab}}"
            />
          {{/if}}
        </:breadcrumbs>
        <:title>
          <span class="tag-settings-title__label">{{i18n
              "tagging.settings.edit_tag_prefix"
            }}</span>
          <span class="tag-settings-title__dropdown">
            <TagDropdown
              aria-label={{i18n "tagging.settings.select_tag"}}
              @tags={{this.tags}}
              @value={{@tag.name}}
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
          <DHorizontalOverflowNav class="d-nav-submenu__tabs">
            <li>
              <LinkTo
                @models={{array
                  @parentParams.tag_slug
                  @parentParams.tag_id
                  "general"
                }}
                @route="tag.edit.tab"
              >
                {{i18n "tagging.settings.general"}}
              </LinkTo>
            </li>
            <li>
              <LinkTo
                @models={{array
                  @parentParams.tag_slug
                  @parentParams.tag_id
                  "localizations"
                }}
                @route="tag.edit.tab"
              >
                {{i18n "tagging.settings.localizations"}}
              </LinkTo>
            </li>
          </DHorizontalOverflowNav>
        </div>
      {{/if}}

      <Form
        class="tag-settings__form"
        @data={{this.formData}}
        @onRegisterApi={{this.registerForm}}
        @onSubmit={{this.save}}
        as |form transientData|
      >
        {{#if (eq @selectedTab "general")}}
          <form.Field
            @format="large"
            @name="name"
            @title={{i18n "tagging.settings.name"}}
            @type="input"
            @validation="required"
            as |field|
          >
            <field.Control
              class="tag-name-input"
              placeholder={{i18n "tagging.settings.name_placeholder"}}
              @maxlength={{this.siteSettings.max_tag_length}}
            />
          </form.Field>

          <form.Field
            @format="large"
            @name="slug"
            @title={{i18n "tagging.settings.slug"}}
            @type="input"
            @validate={{this.validateSlug}}
            as |field|
          >
            <field.Control
              placeholder={{i18n "tagging.settings.slug_placeholder"}}
            />
          </form.Field>

          <form.Field
            @format="large"
            @name="description"
            @title={{i18n "tagging.description"}}
            @type="composer"
            @validation="length:0,1000"
            as |field|
          >
            <field.Control @height={{200}} />
          </form.Field>

          <form.Field
            @description={{i18n
              "tagging.settings.synonyms_subtitle"
              name=@tag.name
            }}
            @format="large"
            @name="synonyms"
            @title={{i18n "tagging.synonyms"}}
            @type="custom"
            as |field|
          >
            <field.Control>
              <MiniTagChooser
                @onChange={{this.handleSynonymChange}}
                @options={{hash
                  everyTag=true
                  allowAny=false
                  blockedTags=this.blockedTags
                  filterPlaceholder="tagging.settings.add_synonym_placeholder"
                  maximum=200
                }}
                @value={{transientData.synonyms}}
              />
            </field.Control>
          </form.Field>
        {{else if (eq @selectedTab "localizations")}}
          <TagSettingsLocalizations
            @form={{form}}
            @localizations={{transientData.localizations}}
            @tagId={{@tag.id}}
          />
        {{/if}}

        <form.Actions>
          <form.Submit id="save-tag" @label="tagging.settings.save" />
        </form.Actions>
      </Form>
    </div>
  </template>
}
