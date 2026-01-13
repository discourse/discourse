import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

/**
 * @component AiRetryStreamingButton
 * @argument post
 */
export default class AiRetryStreamingButton extends Component {
  /**
   * Tracks whether a retry request is currently in-flight.
   *
   * @type {boolean}
   */
  @tracked retrying = false;

  /**
   * Sends a request to retry streaming the current AI response.
   *
   * @returns {Promise<void>}
   */
  @action
  async retry() {
    if (this.retrying) {
      return;
    }

    this.retrying = true;

    try {
      await ajax(`/discourse-ai/ai-bot/post/${this.args.post.id}/retry`, {
        type: "POST",
      });
    } catch (e) {
      popupAjaxError(e);
    } finally {
      this.retrying = false;
    }
  }

  <template>
    <DButton
      class="post-action-menu__ai-retry-streaming ai-retry-streaming"
      ...attributes
      @action={{this.retry}}
      @icon={{if this.retrying "spinner" "arrow-rotate-right"}}
      @title="discourse_ai.ai_bot.try_again"
      @disabled={{this.retrying}}
    />
  </template>
}
