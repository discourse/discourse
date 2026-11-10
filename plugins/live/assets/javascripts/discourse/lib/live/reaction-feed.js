import { tracked } from "@glimmer/tracking";
import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

// Matches the float animation in live-room-page.scss.
export const REACTION_TTL_MS = 4000;
// A burst from a large room would otherwise pile up hundreds of nodes.
export const MAX_VISIBLE_REACTIONS = 40;

let nextId = 0;

// Reactions currently floating over a call. Expiry is timer-driven rather
// than tied to animationend: animations pause in background tabs, which would
// replay a backlog of stale reactions when the user returns.
export default class ReactionFeed {
  @tracked reactions = [];

  #timers = new Map();

  add({ roomId, userId, username, emoji }) {
    const reaction = {
      id: ++nextId,
      roomId: Number(roomId),
      userId: Number(userId),
      username,
      emoji,
      // Percent across the overlay, kept off the edges so the label fits.
      offset: 10 + Math.random() * 80,
    };

    const overflow = Math.max(
      0,
      this.reactions.length + 1 - MAX_VISIBLE_REACTIONS
    );
    for (const dropped of this.reactions.slice(0, overflow)) {
      this.#clearTimer(dropped.id);
    }
    this.reactions = [...this.reactions.slice(overflow), reaction];

    this.#timers.set(
      reaction.id,
      discourseLater(() => this.remove(reaction.id), REACTION_TTL_MS)
    );

    return reaction;
  }

  remove(id) {
    this.#clearTimer(id);
    this.reactions = this.reactions.filter((reaction) => reaction.id !== id);
  }

  forRoom(roomId) {
    return this.reactions.filter(
      (reaction) => reaction.roomId === Number(roomId)
    );
  }

  clearRoom(roomId) {
    for (const reaction of this.forRoom(roomId)) {
      this.remove(reaction.id);
    }
  }

  #clearTimer(id) {
    cancel(this.#timers.get(id));
    this.#timers.delete(id);
  }
}
