import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import TopicDraftsDropdown from "discourse/components/topic-drafts-dropdown";
import DButtonTooltip from "float-kit/components/d-button-tooltip";

@tagName("")
export default class CreateTopicButton extends Component {
  label = "topic.create";
  btnClass = "btn-default";

  <template>
    {{#if this.canCreateTopic}}
      <DButtonTooltip>
        <:button>
          <DButton
            @action={{this.action}}
            @icon="far-pen-to-square"
            @label={{this.label}}
            id="create-topic"
            class={{this.btnClass}}
          />
        </:button>
      </DButtonTooltip>

      {{#if @showDrafts}}
        <TopicDraftsDropdown @disabled={{false}} />
      {{/if}}
    {{/if}}
  </template>
}
