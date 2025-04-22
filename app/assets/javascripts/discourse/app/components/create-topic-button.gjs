import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import TopicDraftsDropdown from "discourse/components/topic-drafts-dropdown";
import { i18n } from "discourse-i18n";
import DButtonTooltip from "float-kit/components/d-button-tooltip";
import DTooltip from "float-kit/components/d-tooltip";

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

  <template>
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
            <DTooltip
              @icon="circle-info"
              @content={{i18n this.disallowedReason}}
            />
          {{/if}}
        </:tooltip>
      </DButtonTooltip>

      {{#if @showDrafts}}
        <TopicDraftsDropdown @disabled={{false}} />
      {{/if}}
    {{/if}}
  </template>
}
