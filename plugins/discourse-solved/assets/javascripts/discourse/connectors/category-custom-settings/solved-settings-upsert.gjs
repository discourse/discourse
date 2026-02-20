import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import withEventValue from "discourse/helpers/with-event-value";
import { i18n } from "discourse-i18n";

export default class SolvedSettingsUpsert extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.enable_simplified_category_creation;
  }

  @service siteSettings;

  @tracked enableAcceptedAnswers;

  constructor() {
    super(...arguments);
    this.enableAcceptedAnswers =
      this.args.outletArgs.category.custom_fields.enable_accepted_answers ===
      "true";
  }

  get customFields() {
    return this.args.outletArgs.category.custom_fields;
  }

  @action
  onToggleAcceptedAnswers() {
    this.enableAcceptedAnswers = !this.enableAcceptedAnswers;
    this.customFields.enable_accepted_answers = this.enableAcceptedAnswers
      ? "true"
      : "false";
  }

  @action
  onAutoCloseHoursChange(value) {
    this.customFields.solved_topics_auto_close_hours = value;
  }

  <template>
    {{#let @outletArgs.form as |form|}}
      <form.Section @title={{i18n "solved.title"}}>
        {{#unless this.siteSettings.allow_solved_on_all_topics}}
          <form.Container @title={{i18n "solved.allow_accepted_answers"}}>
            <DToggleSwitch
              @state={{this.enableAcceptedAnswers}}
              {{on "click" this.onToggleAcceptedAnswers}}
            />
          </form.Container>
        {{/unless}}

        <form.Container @title={{i18n "solved.solved_topics_auto_close_hours"}}>
          <input
            value={{this.customFields.solved_topics_auto_close_hours}}
            {{on "input" (withEventValue this.onAutoCloseHoursChange)}}
            type="number"
            min="0"
          />
        </form.Container>
      </form.Section>
    {{/let}}
  </template>
}
