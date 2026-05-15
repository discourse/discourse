import Component from "@glimmer/component";
import { service } from "@ember/service";
import TopicDraftsDropdown from "discourse/components/topic-drafts-dropdown";
import { applyValueTransformer } from "discourse/lib/transformer";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

export default class CreateTopicButton extends Component {
  @service router;
  @service site;

  get label() {
    const label = this.args.label ?? "topic.create";

    const sharedDraftsCategoryId = this.site.shared_drafts_category_id;
    const currentCategoryId =
      this.router.currentRoute?.attributes?.category?.id;

    if (
      label === "topic.create" &&
      sharedDraftsCategoryId &&
      currentCategoryId === sharedDraftsCategoryId
    ) {
      return "topic.create_shared_draft";
    }

    return label;
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
        @btnId={{this.btnId}}
        @btnClasses={{this.btnClasses}}
        @draftMenuClasses={{this.draftMenuClasses}}
        @showDrafts={{@showDrafts}}
        ...attributes
      />
    {{/if}}
  </template>
}
