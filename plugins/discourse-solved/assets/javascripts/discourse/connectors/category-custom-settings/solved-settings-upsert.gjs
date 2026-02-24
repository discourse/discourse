import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

export default class SolvedSettingsUpsert extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.enable_simplified_category_creation;
  }

  @service siteSettings;

  get enableAcceptedAnswers() {
    const value =
      this.args.outletArgs.transientData?.custom_fields
        ?.enable_accepted_answers;
    return value === "true" || value === true;
  }

  get solvedTopicsAutoCloseHours() {
    return this.args.outletArgs.transientData?.custom_fields
      ?.solved_topics_auto_close_hours;
  }

  @action
  onToggleAcceptedAnswers(value) {
    this.args.outletArgs.form.set(
      "custom_fields.enable_accepted_answers",
      value ? "true" : "false"
    );
  }

  @action
  onAutoCloseHoursChange(value) {
    this.args.outletArgs.form.set(
      "custom_fields.solved_topics_auto_close_hours",
      value
    );
  }

  <template>
    {{#let @outletArgs.form as |form|}}
      <form.Section @title={{i18n "solved.title"}}>
        {{#unless this.siteSettings.allow_solved_on_all_topics}}
          <div
            class="form-kit__container form-kit__field form-kit__field-checkbox"
          >
            <div class="form-kit__container-content">
              <label class="form-kit__control-checkbox-label">
                <input
                  class="form-kit__control-checkbox"
                  type="checkbox"
                  checked={{this.enableAcceptedAnswers}}
                  {{on
                    "change"
                    (withEventValue
                      this.onToggleAcceptedAnswers "target.checked"
                    )
                  }}
                />
                <span class="form-kit__control-checkbox-content">
                  <span class="form-kit__control-checkbox-title">
                    <span>{{i18n "solved.allow_accepted_answers"}}</span>
                  </span>
                </span>
              </label>
            </div>
          </div>
        {{/unless}}

        <form.Container @title={{i18n "solved.solved_topics_auto_close_hours"}}>
          <input
            value={{this.solvedTopicsAutoCloseHours}}
            {{on "input" (withEventValue this.onAutoCloseHoursChange)}}
            type="number"
            min="0"
          />
        </form.Container>
      </form.Section>
    {{/let}}
  </template>
}
