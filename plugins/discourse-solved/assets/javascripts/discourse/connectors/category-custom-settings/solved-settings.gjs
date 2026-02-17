import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

export default class SolvedSettings extends Component {
  @service siteSettings;

  get customFields() {
    return this.args.outletArgs.category.custom_fields;
  }

  @action
  onChangeSetting(value) {
    this.customFields.enable_accepted_answers = value ? "true" : "false";
  }

  @action
  onChangeAutoCloseHours(value) {
    this.customFields.solved_topics_auto_close_hours = value;
  }

  <template>
    <div class="category-custom-settings-outlet solved-settings" ...attributes>
      <h3>{{i18n "solved.title"}}</h3>

      {{#unless this.siteSettings.allow_solved_on_all_topics}}
        <section class="field">
          <div class="enable-accepted-answer">
            <label class="checkbox-label">
              <input
                {{on
                  "change"
                  (withEventValue this.onChangeSetting "target.checked")
                }}
                checked={{@outletArgs.category.enable_accepted_answers}}
                type="checkbox"
              />
              {{i18n "solved.allow_accepted_answers"}}
            </label>
          </div>
        </section>
      {{/unless}}

      <section class="field auto-close-solved-topics">
        <label for="auto-close-solved-topics">
          {{i18n "solved.solved_topics_auto_close_hours"}}
        </label>
        <input
          {{on "input" (withEventValue this.onChangeAutoCloseHours)}}
          value={{@outletArgs.category.custom_fields.solved_topics_auto_close_hours}}
          type="number"
          min="0"
          id="auto-close-solved-topics"
        />
      </section>
    </div>
  </template>
}
