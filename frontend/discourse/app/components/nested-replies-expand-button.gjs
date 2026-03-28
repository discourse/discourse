import Component from "@glimmer/component";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class NestedRepliesExpandButton extends Component {
  static extraControls = true;

  static shouldRender(args, _context, owner) {
    const router = owner.lookup("service:router");
    if (!router.currentRouteName?.startsWith("nested")) {
      return false;
    }

    const post = args.post;
    if (post.post_number === 1) {
      return false;
    }

    if (args.state.repliesShown) {
      return false;
    }

    return (
      (post.direct_reply_count || 0) > 0 ||
      (post.total_descendant_count || 0) > 0
    );
  }

  get replyCount() {
    const post = this.args.post;
    return post.total_descendant_count || post.direct_reply_count || 0;
  }

  get label() {
    return i18n("nested_replies.collapsed_replies", {
      count: this.replyCount,
    });
  }

  <template>
    <DButton
      class="post-action-menu__nested-replies-expand btn-icon-text"
      ...attributes
      @action={{@buttonActions.toggleReplies}}
      @icon="nested-circle-plus"
      @translatedLabel={{this.label}}
    />
  </template>
}
