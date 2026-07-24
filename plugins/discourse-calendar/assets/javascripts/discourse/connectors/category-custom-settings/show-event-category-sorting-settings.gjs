import Component from "@glimmer/component";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";

export default class ShowEventCategorySortingSettings extends Component {
  @service siteSettings;

  get showSection() {
    return (
      this.siteSettings.sort_categories_by_event_start_date_enabled ||
      this.siteSettings.disable_resorting_on_categories_enabled
    );
  }

  <template>
    {{#if this.showSection}}
      <@outletArgs.form.Section
        @title={{i18n
          "discourse_post_event.category.settings_sections.event_sorting"
        }}
        class="category-custom-settings-outlet show-event-category-sorting-settings"
      >
        <@outletArgs.form.Object @name="custom_fields" as |object|>
          {{#if this.siteSettings.sort_categories_by_event_start_date_enabled}}
            <object.Field
              @name="sort_topics_by_event_start_date"
              @title={{i18n
                "discourse_post_event.category.sort_topics_by_event_start_date"
              }}
              @format="max"
              @type="checkbox"
              as |field|
            >
              <field.Control />
            </object.Field>
          {{/if}}

          {{#if this.siteSettings.disable_resorting_on_categories_enabled}}
            <object.Field
              @name="disable_topic_resorting"
              @title={{i18n
                "discourse_post_event.category.disable_topic_resorting"
              }}
              @format="max"
              @type="checkbox"
              as |field|
            >
              <field.Control />
            </object.Field>
          {{/if}}
        </@outletArgs.form.Object>
      </@outletArgs.form.Section>
    {{/if}}
  </template>
}
