import Component from "@glimmer/component";
import { service } from "@ember/service";
import TopicDraftsDropdown from "discourse/components/topic-drafts-dropdown";
import concatClass from "discourse/helpers/concat-class";
import { applyValueTransformer } from "discourse/lib/transformer";

export default class CreateTopicButton extends Component {
  @service router;

  label = this.args.label ?? "topic.create";
  btnId = this.args.btnId ?? "create-topic";

  get btnTypeClass() {
    return this.args.btnTypeClass || "btn-default";
  }

  get btnClasses() {
    const additionalClasses = applyValueTransformer(
      "create-topic-button-class",
      [],
      {
        disabled: this.args.disabled,
        canCreateTopic: this.args.canCreateTopic,
        category: this.router.currentRoute?.attributes?.category,
        tag: this.router.currentRoute?.attributes?.tag,
      }
    );

    return concatClass(
      this.args.btnClass,
      this.btnTypeClass,
      ...additionalClasses
    );
  }

  <template>
    {{#if @canCreateTopic}}
      <TopicDraftsDropdown
        @action={{@action}}
        @label={{this.label}}
        @btnId={{this.btnId}}
        @btnClasses={{this.btnClasses}}
        @btnTypeClass={{this.btnTypeClass}}
        @showDrafts={{@showDrafts}}
        ...attributes
      />
    {{/if}}
  </template>
}
