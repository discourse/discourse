import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import concatClass from "discourse/helpers/concat-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { SEARCH_PRIORITIES } from "discourse/lib/constants";
import getUrl from "discourse/lib/get-url";
import ComboBox from "discourse/select-kit/components/combo-box";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

export default class UpsertCategorySettings extends Component {
  @service siteSettings;

  get emailInEnabled() {
    return this.siteSettings.email_in;
  }

  get showPositionInput() {
    return this.siteSettings.fixed_category_positions;
  }

  get searchPrioritiesOptions() {
    const options = [];

    Object.entries(SEARCH_PRIORITIES).forEach((entry) => {
      const [name, value] = entry;

      options.push({
        name: i18n(`category.search_priority.options.${name}`),
        value,
      });
    });

    return options;
  }

  <template>
    <@form.Section
      class={{concatClass
        "edit-category-tab"
        "edit-category-tab-settings"
        (if (eq @selectedTab "settings") "active")
      }}
    >
      <@form.Field
        @name="slug"
        @title={{i18n "category.slug"}}
        @format="max"
        as |field|
      >
        <field.Input
          placeholder={{i18n "category.slug_placeholder"}}
          @maxlength="255"
        />
      </@form.Field>

      {{#if this.showPositionInput}}
        <@form.Field
          @name="position"
          @title={{i18n "category.position"}}
          @format="max"
          as |field|
        >
          <field.Input type="number" min="0" />
        </@form.Field>
      {{/if}}

      <@form.Field
        @name="num_featured_topics"
        @title={{if
          @category.parent_category_id
          (i18n "category.subcategory_num_featured_topics")
          (i18n "category.num_featured_topics")
        }}
        @format="max"
        as |field|
      >
        <field.Input type="number" min="1" />
      </@form.Field>

      <@form.Field
        @name="search_priority"
        @title={{i18n "category.search_priority.label"}}
        @format="max"
        as |field|
      >
        <field.Custom>
          <ComboBox
            @valueProperty="value"
            @id="category-search-priority"
            @content={{this.searchPrioritiesOptions}}
            @value={{field.value}}
            @onChange={{field.set}}
            @options={{hash placementStrategy="absolute"}}
          />
        </field.Custom>
      </@form.Field>

      {{#if this.siteSettings.enable_badges}}
        <@form.Field
          @name="allow_badges"
          @title={{i18n "category.allow_badges_label"}}
          @format="max"
          as |field|
        >
          <field.Checkbox />
        </@form.Field>
      {{/if}}

      {{#if this.siteSettings.topic_featured_link_enabled}}
        <@form.Field
          @name="topic_featured_link_allowed"
          @title={{i18n "category.topic_featured_link_allowed"}}
          @format="max"
          as |field|
        >
          <field.Checkbox />
        </@form.Field>
      {{/if}}

      <@form.Field
        @name="navigate_to_first_post_after_read"
        @title={{i18n "category.navigate_to_first_post_after_read"}}
        @format="max"
        as |field|
      >
        <field.Checkbox />
      </@form.Field>

      <@form.Field
        @name="all_topics_wiki"
        @title={{i18n "category.all_topics_wiki"}}
        @format="max"
        as |field|
      >
        <field.Checkbox />
      </@form.Field>

      <@form.Field
        @name="allow_unlimited_owner_edits_on_first_post"
        @title={{i18n "category.allow_unlimited_owner_edits_on_first_post"}}
        @format="max"
        as |field|
      >
        <field.Checkbox />
      </@form.Field>

      <@form.Section @title={{i18n "category.settings_sections.email"}}>
        {{#if this.emailInEnabled}}
          <@form.Field
            @name="email_in"
            @title={{i18n "category.email_in"}}
            @format="max"
            as |field|
          >
            <field.Input @maxlength="255" />
          </@form.Field>

          <@form.Field
            @name="email_in_allow_strangers"
            @title={{i18n "category.email_in_allow_strangers"}}
            @format="max"
            as |field|
          >
            <field.Checkbox />
          </@form.Field>

          <@form.Field
            @name="mailinglist_mirror"
            @title={{i18n "category.mailinglist_mirror"}}
            @format="max"
            as |field|
          >
            <field.Checkbox />
          </@form.Field>

          <PluginOutlet
            @name="category-email-in"
            @connectorTagName="div"
            @outletArgs={{lazyHash category=@category form=@form}}
          />
        {{else}}
          <@form.Alert @type="info">
            {{htmlSafe
              (i18n
                "category.email_in_disabled"
                setting_url=(getUrl
                  "/admin/site_settings/category/all_results?filter=email_in"
                )
              )
            }}
          </@form.Alert>
        {{/if}}
      </@form.Section>

      <PluginOutlet
        @name="category-custom-settings"
        @outletArgs={{lazyHash
          category=@category
          form=@form
          transientData=@transientData
        }}
      />
    </@form.Section>
  </template>
}
