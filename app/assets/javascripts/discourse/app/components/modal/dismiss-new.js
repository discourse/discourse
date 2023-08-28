import Component from "@glimmer/component";
import { action, computed } from "@ember/object";

export default class DismissNew extends Component {
  dismissTopics = true;
  dismissPosts = true;
  untrack = false;

  constructor() {
    super(...arguments);

    if (this.args.model.subset === "replies") {
      this.dismissTopics = false;
    }
    if (this.args.model.subset === "topics") {
      this.dismissPosts = false;
    }
  }

  @computed("args.model.selectedTopics")
  get partialDismiss() {
    return (this.args.model.selectedTopics?.length || 0) !== 0;
  }

  @computed("partialDismiss")
  get dismissNewTopicsLabel() {
    return (
      "topics.bulk.dismiss_new_modal.topics" +
      (this.partialDismiss ? "_with_count" : "")
    );
  }

  @computed("partialDismiss")
  get dismissNewRepliesLabel() {
    return (
      "topics.bulk.dismiss_new_modal.replies" +
      (this.partialDismiss ? "_with_count" : "")
    );
  }

  @computed("args.model.selectedTopics", "args.model.subset")
  get showDismissNewTopics() {
    if (!this.partialDismiss) {
      return this.args.model.subset === "topics" || !this.args.model.subset;
    }
    return this.countNewTopics > 0;
  }

  @computed("args.model.selectedTopics")
  get showDismissNewReplies() {
    if (!this.partialDismiss) {
      return this.args.model.subset === "replies" || !this.args.model.subset;
    }
    return this.countNewReplies > 0;
  }

  @computed("args.model.selectedTopics")
  get countNewTopics() {
    const topics = this.args.model.selectedTopics;
    if (!topics?.length) {
      return 0;
    }

    return topics.filter((topic) => !topic.unread_posts).length;
  }

  @computed("args.model.selectedTopics")
  get countNewReplies() {
    const topics = this.args.model.selectedTopics;
    if (!topics?.length) {
      return 0;
    }
    return topics.filter((topic) => topic.unread_posts).length;
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
}
