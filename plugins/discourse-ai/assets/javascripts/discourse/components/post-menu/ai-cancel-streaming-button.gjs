import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

export default class AiCancelStreamingButton extends Component {
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
    <DButton
      class="post-action-menu__ai-cancel-streaming cancel-streaming"
      ...attributes
      @action={{this.cancelStreaming}}
      @icon="pause"
      @title="discourse_ai.ai_bot.cancel_streaming"
    />
  </template>
}
