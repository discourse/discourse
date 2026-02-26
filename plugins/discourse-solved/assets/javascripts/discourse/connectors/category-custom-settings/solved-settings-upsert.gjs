import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
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
    return value?.toString() === "true";
  }

  @action
  async onToggleAcceptedAnswers(_, { set, name }) {
    await set(name, !this.enableAcceptedAnswers);
  }

  <template>
    {{#let @outletArgs.form as |form|}}
      <form.Section @title={{i18n "solved.title"}}>
        <form.Object @name="custom_fields" as |customFields|>
          {{#unless this.siteSettings.allow_solved_on_all_topics}}
            <customFields.Field
              @name="enable_accepted_answers"
              @title={{i18n "solved.allow_accepted_answers"}}
              @onSet={{this.onToggleAcceptedAnswers}}
              as |field|
            >
              <field.Checkbox checked={{this.enableAcceptedAnswers}} />
            </customFields.Field>
          {{/unless}}

          <customFields.Field
            @name="solved_topics_auto_close_hours"
            @title={{i18n "solved.solved_topics_auto_close_hours"}}
            as |field|
          >
            <field.Input @type="number" min="0" />
          </customFields.Field>
        </form.Object>
      </form.Section>
    {{/let}}
  </template>
}
