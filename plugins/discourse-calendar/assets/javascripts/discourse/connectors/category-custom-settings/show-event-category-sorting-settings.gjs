import Component, { Input } from "@ember/component";
import { tagName } from "@ember-decorators/component";
import { or } from "truth-helpers";
import { i18n } from "discourse-i18n";

@tagName("")
export default class ShowEventCategorySortingSettings extends Component {
  <template>
    {{#if
      (or
        this.siteSettings.sort_categories_by_event_start_date_enabled
        this.siteSettings.disable_resorting_on_categories_enabled
      )
    }}
      <section>
        <h3>{{i18n
            "discourse_post_event.category.settings_sections.event_sorting"
          }}</h3>

        {{#if this.siteSettings.sort_categories_by_event_start_date_enabled}}
          <section class="field show-subcategory-list-field">
            <label>
              <Input
                @type="checkbox"
                @checked={{this.category.custom_fields.sort_topics_by_event_start_date}}
              />
              {{i18n
                "discourse_post_event.category.sort_topics_by_event_start_date"
              }}
            </label>
          </section>
        {{/if}}

        {{#if this.siteSettings.disable_resorting_on_categories_enabled}}
          <section class="field show-subcategory-list-field">
            <label>
              <Input
                @type="checkbox"
                @checked={{this.category.custom_fields.disable_topic_resorting}}
              />
              {{i18n "discourse_post_event.category.disable_topic_resorting"}}
            </label>
          </section>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
