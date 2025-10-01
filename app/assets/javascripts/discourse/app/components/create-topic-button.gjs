import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import DButton from "discourse/components/d-button";
import TopicDraftsDropdown from "discourse/components/topic-drafts-dropdown";
import concatClass from "discourse/helpers/concat-class";

export default class CreateTopicButton extends Component {
  @tracked btnTypeClass = this.args.btnTypeClass || "btn-default";
  @tracked label = this.args.label ?? "topic.create";

  btnId = this.args.btnId ?? "create-topic";

  <template>
    {{#if @canCreateTopic}}
      <DButton
        @action={{@action}}
        @icon="far-pen-to-square"
        @label={{this.label}}
        id={{this.btnId}}
        class={{concatClass @btnClass this.btnTypeClass}}
      />

      {{#if @showDrafts}}
        <TopicDraftsDropdown
          @disabled={{false}}
          @btnTypeClass={{this.btnTypeClass}}
        />
      {{/if}}
    {{/if}}
  </template>
}
