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

  /**
   * Classes for the button half only. The variant is not repeated here; it goes
   * to the group as `@btnTypeClass`, which applies it to both halves.
   */
  get btnClasses() {
    const additionalClasses = applyValueTransformer(
      "create-topic-button-class",
      [],
      this.transformerContext
    );

    return dConcatClass(this.args.btnClass, ...additionalClasses);
  }

  /** Classes for the drafts menu half only. */
  get draftMenuClasses() {
    const additionalClasses = applyValueTransformer(
      "create-topic-button-draft-menu-class",
      [],
      this.transformerContext
    );

    return dConcatClass(...additionalClasses);
  }

  <template>
    {{#if @canCreateTopic}}
      <TopicDraftsDropdown
        ...attributes
        @action={{@action}}
        @btnClasses={{this.btnClasses}}
        @btnId={{this.btnId}}
        @btnTypeClass={{this.btnTypeClass}}
        @draftMenuClasses={{this.draftMenuClasses}}
        @icon={{@icon}}
        @label={{this.label}}
        @showDrafts={{@showDrafts}}
      />
    {{/if}}
  </template>
}
