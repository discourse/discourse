import Component from "@glimmer/component";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import { SEARCH_PRIORITIES } from "discourse/lib/constants";
import getUrl from "discourse/lib/get-url";
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
    <@form.Field
      @format="max"
      @name="slug"
      @title={{i18n "category.slug"}}
      @type="input"
      as |field|
    >
      <field.Control
        placeholder={{i18n "category.slug_placeholder"}}
        @maxlength="255"
      />
    </@form.Field>

    {{#if this.showPositionInput}}
      <@form.Field
        @format="max"
        @name="position"
        @title={{i18n "category.position"}}
        @type="input-number"
        as |field|
      >
        <field.Control min="0" />
      </@form.Field>
    {{/if}}

    <@form.Field
      @name="num_featured_topics"
      @title={{if
        @category.parent_category_id
        (i18n "category.subcategory_num_featured_topics")
        (i18n "category.num_featured_topics")
      }}
      @type="input-number"
      as |field|
    >
      <field.Control min="1" />
    </@form.Field>

    <@form.Field
      @format="max"
      @name="search_priority"
      @title={{i18n "category.search_priority.label"}}
      @type="select"
      @validation="required"
      as |field|
    >
      <field.Control @includeNone={{false}} as |select|>
        {{#each this.searchPrioritiesOptions as |searchPriority|}}
          <select.Option
            @value={{searchPriority.value}}
          >{{searchPriority.name}}</select.Option>
        {{/each}}
      </field.Control>
    </@form.Field>

    {{#if this.siteSettings.enable_badges}}
      <@form.Field
        @format="max"
        @name="allow_badges"
        @title={{i18n "category.allow_badges_label"}}
        @type="checkbox"
        as |field|
      >
        <field.Control />
      </@form.Field>
    {{/if}}

    {{#if this.siteSettings.topic_featured_link_enabled}}
      <@form.Field
        @format="max"
        @name="topic_featured_link_allowed"
        @title={{i18n "category.topic_featured_link_allowed"}}
        @type="checkbox"
        as |field|
      >
        <field.Control />
      </@form.Field>
    {{/if}}

    <@form.Field
      @format="max"
      @name="navigate_to_first_post_after_read"
      @title={{i18n "category.navigate_to_first_post_after_read"}}
      @type="checkbox"
      as |field|
    >
      <field.Control />
    </@form.Field>

    <@form.Field
      @format="max"
      @name="all_topics_wiki"
      @title={{i18n "category.all_topics_wiki"}}
      @type="checkbox"
      as |field|
    >
      <field.Control />
    </@form.Field>

    <@form.Field
      @format="max"
      @name="allow_unlimited_owner_edits_on_first_post"
      @title={{i18n "category.allow_unlimited_owner_edits_on_first_post"}}
      @type="checkbox"
      as |field|
    >
      <field.Control />
    </@form.Field>

    <@form.Section @title={{i18n "category.settings_sections.email"}}>
      {{#if this.emailInEnabled}}
        <@form.Field
          @format="max"
          @name="email_in"
          @title={{i18n "category.email_in"}}
          @type="input"
          as |field|
        >
          <field.Control @maxlength="255" />
        </@form.Field>

        <@form.Field
          @format="max"
          @name="email_in_allow_strangers"
          @title={{i18n "category.email_in_allow_strangers"}}
          @type="checkbox"
          as |field|
        >
          <field.Control />
        </@form.Field>

        <@form.Field
          @format="max"
          @name="mailinglist_mirror"
          @title={{i18n "category.mailinglist_mirror"}}
          @type="checkbox"
          as |field|
        >
          <field.Control />
        </@form.Field>

        <PluginOutlet
          @connectorTagName="div"
          @name="category-email-in"
          @outletArgs={{lazyHash category=@category form=@form}}
        />
      {{else}}
        <@form.Alert @type="info">
          {{trustHTML
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
  </template>
}
