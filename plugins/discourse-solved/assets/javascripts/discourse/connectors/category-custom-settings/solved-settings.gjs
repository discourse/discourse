import Component from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { classNames, tagName } from "@ember-decorators/component";
import { i18n } from "discourse-i18n";

@tagName("")
@classNames("category-custom-settings-outlet", "solved-settings")
export default class SolvedSettings extends Component {
  @action
  onChangeSetting(value) {
    this.set(
      "category.custom_fields.enable_accepted_answers",
      value ? "true" : "false"
    );
  }

  <template>
    <h3>{{i18n "solved.title"}}</h3>

    {{#unless this.siteSettings.allow_solved_on_all_topics}}
      <section class="field">
        <div class="enable-accepted-answer">
          <label class="checkbox-label">
            <input
              {{! template-lint-disable no-action }}
              {{on "change" (action "onChangeSetting" value="target.checked")}}
              checked={{this.category.enable_accepted_answers}}
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
        {{! template-lint-disable no-action }}
        {{on
          "input"
          (action
            (mut this.category.custom_fields.solved_topics_auto_close_hours)
            value="target.value"
          )
        }}
        value={{this.category.custom_fields.solved_topics_auto_close_hours}}
        type="number"
        min="0"
        id="auto-close-solved-topics"
      />
    </section>
  </template>
}
