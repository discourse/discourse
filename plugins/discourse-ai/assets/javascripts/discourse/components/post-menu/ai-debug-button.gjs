import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import { isPostFromAiBot } from "../../lib/ai-bot-helper";
import DebugAiModal from "../modal/debug-ai-modal";

export default class AiDebugButton extends Component {
  static shouldRender(args) {
    return isPostFromAiBot(args.post, args.state.currentUser);
  }

  @service modal;

  @action
  debugAiResponse() {
    this.modal.show(DebugAiModal, { model: this.args.post });
  }

  <template>
    <DButton
      class="post-action-menu__debug-ai"
      ...attributes
      @action={{this.debugAiResponse}}
      @icon="info"
      @title="discourse_ai.ai_bot.debug_ai"
    />
  </template>
}
