import { tracked } from "@glimmer/tracking";
import { cancel } from "@ember/runloop";
import Service, { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseLater from "discourse/lib/later";
import ReactionFeed from "../../lib/live/reaction-feed.js";

// Emoji reactions floating over a call. Room messages reach this through the
// live-webrtc service, which only forwards them for the call we're in.
export default class LiveReactionsService extends Service {
  @service currentUser;
  @service liveWebrtc;

  @tracked rateLimited = false;

  #feed = new ReactionFeed();
  #rateLimitTimer = null;

  willDestroy() {
    super.willDestroy(...arguments);
    cancel(this.#rateLimitTimer);
  }

  reactionsFor(roomId) {
    return this.#feed.forRoom(roomId);
  }

  // Shown locally straight away for instant feedback; the broadcast echo of
  // our own reaction is ignored.
  async send(roomId, emoji) {
    if (this.rateLimited) {
      return;
    }

    const reaction = this.#feed.add({
      roomId,
      userId: this.currentUser.id,
      username: this.currentUser.username,
      emoji,
    });

    try {
      await ajax(`/live/rooms/${roomId}/reaction`, {
        type: "POST",
        data: {
          emoji,
          participant_session_id:
            this.liveWebrtc.participantSessionIdFor(roomId),
        },
      });
    } catch (error) {
      this.#feed.remove(reaction.id);
      // Hitting the rate limit mid-burst isn't worth a popup; the picker
      // disables itself until the server's window reopens instead.
      if (error?.jqXHR?.status === 429) {
        this.#holdUntilRateLimitLifts(
          error.jqXHR.responseJSON?.extras?.wait_seconds ?? 1
        );
      } else {
        popupAjaxError(error);
      }
    }
  }

  receive(roomId, payload) {
    if (Number(payload.user_id) === this.currentUser?.id) {
      return;
    }

    this.#feed.add({
      roomId,
      userId: payload.user_id,
      username: payload.username,
      emoji: payload.emoji,
    });
  }

  clearRoom(roomId) {
    this.#feed.clearRoom(roomId);
  }

  #holdUntilRateLimitLifts(waitSeconds) {
    this.rateLimited = true;
    cancel(this.#rateLimitTimer);
    this.#rateLimitTimer = discourseLater(
      () => {
        this.rateLimited = false;
        this.#rateLimitTimer = null;
      },
      Math.max(1, waitSeconds) * 1000
    );
  }
}
