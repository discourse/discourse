import Component from "@glimmer/component";
import { service } from "@ember/service";
import TopicDraftsDropdown from "discourse/components/topic-drafts-dropdown";
import { applyValueTransformer } from "discourse/lib/transformer";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class CreateTopicButton extends Component {
  @service router;

  get label() {
    return this.args.label ?? "topic.create";
  }

  get btnId() {
    return this.args.btnId ?? "create-topic";
  }

  get btnTypeClass() {
    return this.args.btnTypeClass || "btn-default";
  }

  get transformerContext() {
    return {
      disabled: this.args.disabled,
      canCreateTopic: this.args.canCreateTopic,
      category: this.router.currentRoute?.attributes?.category,
      tag: this.router.currentRoute?.attributes?.tag,
    };
  }

  get btnClasses() {
    const additionalClasses = applyValueTransformer(
      "create-topic-button-class",
      [],
      this.transformerContext
    );

    return dConcatClass(
      this.args.btnClass,
      this.btnTypeClass,
      ...additionalClasses
    );
  }

  get draftMenuClasses() {
    const additionalClasses = applyValueTransformer(
      "create-topic-button-draft-menu-class",
      [],
      this.transformerContext
    );

    return dConcatClass(this.btnTypeClass, ...additionalClasses);
  }

  <template>
    {{#if @canCreateTopic}}
      <TopicDraftsDropdown
        @action={{@action}}
        @label={{this.label}}
        @icon={{@icon}}
        @btnId={{this.btnId}}
        @btnClasses={{this.btnClasses}}
        @draftMenuClasses={{this.draftMenuClasses}}
        @showDrafts={{@showDrafts}}
        ...attributes
      />
    {{/if}}
  </template>
}
