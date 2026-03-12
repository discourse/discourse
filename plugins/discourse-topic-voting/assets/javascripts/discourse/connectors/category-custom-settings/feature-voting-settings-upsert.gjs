import Component from "@glimmer/component";
import { action } from "@ember/object";
import { i18n } from "discourse-i18n";

export default class FeatureVotingSettingsUpsert extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.enable_simplified_category_creation;
  }

  get enableTopicVoting() {
    const value =
      this.args.outletArgs.transientData?.custom_fields?.enable_topic_voting;
    return value?.toString() === "true";
  }

  @action
  async onToggleTopicVoting(_, { set, name }) {
    await set(name, this.enableTopicVoting ? "false" : "true");
  }

  <template>
    {{#let @outletArgs.form as |form|}}
      <form.Section @title={{i18n "topic_voting.title"}}>
        <form.Object @name="custom_fields" as |customFields|>
          <customFields.Field
            @name="enable_topic_voting"
            @title={{i18n "topic_voting.allow_topic_voting"}}
            @onSet={{this.onToggleTopicVoting}}
            as |field|
          >
            <field.Checkbox checked={{this.enableTopicVoting}} />
          </customFields.Field>
        </form.Object>
      </form.Section>
    {{/let}}
  </template>
}
