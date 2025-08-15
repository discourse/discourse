/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import TopicDraftsDropdown from "discourse/components/topic-drafts-dropdown";

@tagName("")
export default class CreateTopicButton extends Component {
  label = "topic.create";
  btnClass = "btn-default";

  <template>
    {{#if this.canCreateTopic}}
      <DButton
        @action={{this.action}}
        @icon="far-pen-to-square"
        @label={{this.label}}
        id="create-topic"
        class={{this.btnClass}}
      />

      {{#if @showDrafts}}
        <TopicDraftsDropdown @disabled={{false}} />
      {{/if}}
    {{/if}}
  </template>
}
