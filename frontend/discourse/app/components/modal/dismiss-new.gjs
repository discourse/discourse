import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import PreferenceCheckbox from "discourse/components/preference-checkbox";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class DismissNew extends Component {
  @tracked untrack = false;
  @tracked dismissTopics = true;
  @tracked dismissPosts = true;

  constructor() {
    super(...arguments);

    if (this.args.model.subset === "replies") {
      this.dismissTopics = false;
    }
    if (this.args.model.subset === "topics") {
      this.dismissPosts = false;
    }
  }

  get partialDismiss() {
    return (this.selectedTopics?.length || 0) !== 0;
  }

  get dismissNewTopicsLabel() {
    return (
      "topics.bulk.dismiss_new_modal.topics" +
      (this.partialDismiss ? "_with_count" : "")
    );
  }

  get dismissNewRepliesLabel() {
    return (
      "topics.bulk.dismiss_new_modal.replies" +
      (this.partialDismiss ? "_with_count" : "")
    );
  }

  get showDismissNewTopics() {
    return this.partialDismiss ? this.countNewTopics > 0 : true;
  }

  get showDismissNewReplies() {
    return this.partialDismiss ? this.countNewReplies > 0 : true;
  }

  get countNewTopics() {
    const topics = this.selectedTopics;
    if (!topics?.length) {
      return 0;
    }

    return topics.filter((topic) => !topic.unread_posts).length;
  }

  get countNewReplies() {
    const topics = this.selectedTopics;
    if (!topics?.length) {
      return 0;
    }
    return topics.filter((topic) => topic.unread_posts).length;
  }

  get subset() {
    return this.args.model.subset;
  }

  get selectedTopics() {
    return this.args.model.selectedTopics;
  }

  get modalTitle() {
    return i18n("topics.bulk.dismiss_new_modal.title");
  }

  @action
  dismissed() {
    this.args.model.dismissCallback({
      dismissTopics: this.dismissTopics,
      dismissPosts: this.dismissPosts,
      untrack: this.untrack,
    });

    this.args.closeModal();
  }

  <template>
    <DModal
      @closeModal={{@closeModal}}
      @inline={{@inline}}
      @title={{this.modalTitle}}
    >
      <:body>
        <p>
          {{#if this.showDismissNewTopics}}
            <PreferenceCheckbox
              class="dismiss-topics"
              @checked={{this.dismissTopics}}
              @labelCount={{this.countNewTopics}}
              @labelKey={{this.dismissNewTopicsLabel}}
            />
          {{/if}}
          {{#if this.showDismissNewReplies}}
            <PreferenceCheckbox
              class="dismiss-posts"
              @checked={{this.dismissPosts}}
              @labelCount={{this.countNewReplies}}
              @labelKey={{this.dismissNewRepliesLabel}}
            />
          {{/if}}
          <PreferenceCheckbox
            class="untrack"
            @checked={{this.untrack}}
            @labelKey="topics.bulk.dismiss_new_modal.untrack"
          />
        </p>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          id="dismiss-read-confirm"
          @action={{this.dismissed}}
          @icon="check"
          @label="topics.bulk.dismiss"
        />
      </:footer>
    </DModal>
  </template>
}
