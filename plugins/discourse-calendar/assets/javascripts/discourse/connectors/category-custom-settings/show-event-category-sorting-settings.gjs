import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
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

  @action
  onChangeSortByEventStartDate(event) {
    this.args.outletArgs.category.set(
      "custom_fields.sort_topics_by_event_start_date",
      event.target.checked
    );
  }

  @action
  onChangeDisableTopicResorting(event) {
    this.args.outletArgs.category.set(
      "custom_fields.disable_topic_resorting",
      event.target.checked
    );
  }

  <template>
    {{#if this.showSection}}
      {{#if this.siteSettings.enable_simplified_category_creation}}
        <@outletArgs.form.Section
          @title={{i18n
            "discourse_post_event.category.settings_sections.event_sorting"
          }}
          class="category-custom-settings-outlet show-event-category-sorting-settings"
        >
          <@outletArgs.form.Object @name="custom_fields" as |object|>
            {{#if
              this.siteSettings.sort_categories_by_event_start_date_enabled
            }}
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
      {{else}}
        <div
          class="category-custom-settings-outlet show-event-category-sorting-settings"
        >
          <h3>{{i18n
              "discourse_post_event.category.settings_sections.event_sorting"
            }}</h3>

          {{#if this.siteSettings.sort_categories_by_event_start_date_enabled}}
            <section class="field">
              <label class="checkbox-label">
                <input
                  id="sort-topics-by-event-start-date"
                  type="checkbox"
                  checked={{@outletArgs.category.custom_fields.sort_topics_by_event_start_date}}
                  {{on "change" this.onChangeSortByEventStartDate}}
                />
                {{i18n
                  "discourse_post_event.category.sort_topics_by_event_start_date"
                }}
              </label>
            </section>
          {{/if}}

          {{#if this.siteSettings.disable_resorting_on_categories_enabled}}
            <section class="field">
              <label class="checkbox-label">
                <input
                  id="disable-topic-resorting"
                  type="checkbox"
                  checked={{@outletArgs.category.custom_fields.disable_topic_resorting}}
                  {{on "change" this.onChangeDisableTopicResorting}}
                />
                {{i18n "discourse_post_event.category.disable_topic_resorting"}}
              </label>
            </section>
          {{/if}}
        </div>
      {{/if}}
    {{/if}}
  </template>
}
