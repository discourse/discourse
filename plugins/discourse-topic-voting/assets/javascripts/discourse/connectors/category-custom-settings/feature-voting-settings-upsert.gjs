import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DToggleSwitch from "discourse/components/d-toggle-switch";
import { i18n } from "discourse-i18n";

export default class FeatureVotingSettingsUpsert extends Component {
  static shouldRender(args, context) {
    return context.siteSettings.enable_simplified_category_creation;
  }

  @tracked enableTopicVoting;

  constructor() {
    super(...arguments);
    const value =
      this.args.outletArgs.category.custom_fields.enable_topic_voting;
    this.enableTopicVoting = value === "true" || value === true;
  }

  get customFields() {
    return this.args.outletArgs.category.custom_fields;
  }

  @action
  onToggleTopicVoting() {
    this.enableTopicVoting = !this.enableTopicVoting;
    this.customFields.enable_topic_voting = this.enableTopicVoting
      ? "true"
      : "false";
  }

  <template>
    {{#let @outletArgs.form as |form|}}
      <form.Section @title={{i18n "topic_voting.title"}}>
        <form.Container @title={{i18n "topic_voting.allow_topic_voting"}}>
          <DToggleSwitch
            @state={{this.enableTopicVoting}}
            {{on "click" this.onToggleTopicVoting}}
          />
        </form.Container>
      </form.Section>
    {{/let}}
  </template>
}
