import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class CreateTopicButton extends Component {
  label = "topic.create";
  btnClass = "btn-default";

  get disallowedReason() {
    if (this.canCreateTopicOnTag === false) {
      return "topic.create_disabled_tag";
    } else if (this.disabled) {
      return "topic.create_disabled_category";
    }
  }
}
{{#if this.canCreateTopic}}
  <DButtonTooltip>
    <:button>
      <DButton
        @action={{this.action}}
        @icon="far-pen-to-square"
        @disabled={{this.disabled}}
        @label={{this.label}}
        id="create-topic"
        class={{this.btnClass}}
      />
    </:button>
    <:tooltip>
      {{#if @disabled}}
        <DTooltip @icon="circle-info" @content={{i18n this.disallowedReason}} />
      {{/if}}
    </:tooltip>
  </DButtonTooltip>

  {{#if @showDrafts}}
    <TopicDraftsDropdown @disabled={{this.disabled}} />
  {{/if}}
{{/if}}