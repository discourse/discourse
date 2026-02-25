import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

export default class SolvedSettings extends Component {
  @service siteSettings;

  @tracked
  enableAcceptedAnswers =
    this.args.outletArgs.category.custom_fields.enable_accepted_answers ===
    "true";

  get customFields() {
    return this.args.outletArgs.category.custom_fields;
  }

  @action
  onChangeSetting(event) {
    this.enableAcceptedAnswers = event.target.checked;
    this.customFields.enable_accepted_answers = event.target.checked
      ? "true"
      : "false";
  }

  @action
  onChangeAutoCloseHours(value) {
    this.customFields.solved_topics_auto_close_hours = value;
  }

  <template>
    <@outletArgs.form.Section @title={{i18n "solved.title"}} ...attributes>
      {{#unless this.siteSettings.allow_solved_on_all_topics}}
        <@outletArgs.form.Container>
          <label class="checkbox-label">
            <input
              type="checkbox"
              checked={{this.enableAcceptedAnswers}}
              {{on "change" this.onChangeSetting}}
            />
            {{i18n "solved.allow_accepted_answers"}}
          </label>
        </@outletArgs.form.Container>
      {{/unless}}

      <@outletArgs.form.Container
        @title={{i18n "solved.solved_topics_auto_close_hours"}}
      >
        <input
          {{on "input" (withEventValue this.onChangeAutoCloseHours)}}
          value={{this.customFields.solved_topics_auto_close_hours}}
          type="number"
          min="0"
          id="auto-close-solved-topics"
        />
      </@outletArgs.form.Container>
    </@outletArgs.form.Section>
  </template>
}
