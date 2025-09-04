import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import DButton from "discourse/components/d-button";
import TopicDraftsDropdown from "discourse/components/topic-drafts-dropdown";
import concatClass from "discourse/helpers/concat-class";
import { i18n } from "discourse-i18n";
import DButtonTooltip from "float-kit/components/d-button-tooltip";
import DTooltip from "float-kit/components/d-tooltip";

export default class CreateTopicButton extends Component {
  @tracked btnTypeClass = this.args.btnTypeClass || "btn-default";
  label = "topic.create";

  get disallowedReason() {
    if (this.args.canCreateTopicOnTag === false) {
      return "topic.create_disabled_tag";
    } else if (this.args.disabled) {
      return "topic.create_disabled_category";
    }
  }

  <template>
    {{#if @canCreateTopic}}
      <DButtonTooltip>
        <:button>
          <DButton
            @action={{@action}}
            @icon="far-pen-to-square"
            @disabled={{@disabled}}
            @label={{this.label}}
            id="create-topic"
            class={{concatClass @btnClass this.btnTypeClass}}
          />
        </:button>
        <:tooltip>
          {{#if @disabled}}
            <DTooltip
              @icon="circle-info"
              @content={{i18n this.disallowedReason}}
            />
          {{/if}}
        </:tooltip>
      </DButtonTooltip>

      {{#if @showDrafts}}
        <TopicDraftsDropdown
          @disabled={{false}}
          @btnTypeClass={{this.btnTypeClass}}
        />
      {{/if}}
    {{/if}}
  </template>
}
