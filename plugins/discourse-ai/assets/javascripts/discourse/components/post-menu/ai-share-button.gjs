import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { isPostFromAiBot } from "../../lib/ai-bot-helper";
import copyConversation from "../../lib/copy-conversation";
import ShareModal from "../modal/share-modal";

const AUTO_COPY_THRESHOLD = 4;

export default class AiDebugButton extends Component {
  static shouldRender(args) {
    return isPostFromAiBot(args.post, args.state.currentUser);
  }

  @service modal;

  @action
  async shareAiResponse() {
    const post = this.args.post;

    if (post.post_number <= AUTO_COPY_THRESHOLD) {
      await copyConversation(post.topic, 1, post.post_number);
      this.args.showFeedback("discourse_ai.ai_bot.conversation_shared");
    } else {
      this.modal.show(ShareModal, { model: post });
    }
  }

  <template>
    <DButton
      class="post-action-menu__share-ai"
      ...attributes
      @action={{this.shareAiResponse}}
      @icon="far-copy"
      @title="discourse_ai.ai_bot.share"
    />
  </template>
}
