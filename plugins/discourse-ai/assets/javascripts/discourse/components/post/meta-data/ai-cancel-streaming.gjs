import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

/**
 * @component AiCancelStreaming
 * @argument post
 */
export default class AiCancelStreaming extends Component {
  @action
  async cancelStreaming() {
    const post = this.args.post;

    try {
      await ajax(`/discourse-ai/ai-bot/post/${post.id}/stop-streaming`, {
        type: "POST",
      });

      document
        .querySelector(`#post_${post.post_number}`)
        .classList.remove("streaming");
    } catch (e) {
      popupAjaxError(e);
    }
  }

  <template>
    <div class="post-info ai-cancel-streaming-container">
      <DButton
        class="btn-transparent ai-cancel-streaming"
        @action={{this.cancelStreaming}}
        @icon="pause"
        @label="discourse_ai.ai_bot.cancel_streaming"
      />
    </div>
  </template>
}
