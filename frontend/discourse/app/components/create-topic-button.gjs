import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import TopicDraftsDropdown from "discourse/components/topic-drafts-dropdown";
import concatClass from "discourse/helpers/concat-class";
import { applyValueTransformer } from "discourse/lib/transformer";

export default class CreateTopicButton extends Component {
  @service router;

  @tracked btnTypeClass = this.args.btnTypeClass || "btn-default";
  @tracked label = this.args.label ?? "topic.create";

  btnId = this.args.btnId ?? "create-topic";

  get btnClasses() {
    const permission = applyValueTransformer("create-topic-button-class", "", {
      disabled: this.args.disabled,
      canCreateTopic: this.args.canCreateTopic,
      category: this.router.currentRoute?.attributes?.category,
      tag: this.router.currentRoute?.attributes?.tag,
    });

    return concatClass(this.args.btnClass, this.btnTypeClass, permission);
  }

  <template>
    {{#if @canCreateTopic}}
      <DButton
        @action={{@action}}
        @icon="far-pen-to-square"
        @label={{this.label}}
        id={{this.btnId}}
        class={{this.btnClasses}}
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
