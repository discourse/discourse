import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";

export default class ChatPanePendingManager extends Service {
  @service appEvents;

  @tracked totalPendingMessageCount = 0;
  #countsByContext = new Map();

  increment(contextKey, count = 1) {
    if (!contextKey || count <= 0) {
      return;
    }

    const current = this.#countsByContext.get(contextKey) || 0;
    this.#setCount(contextKey, current + count);
  }

  decrement(contextKey, count = 1) {
    if (!contextKey || count <= 0) {
      return;
    }

    const current = this.#countsByContext.get(contextKey);
    if (!current) {
      return;
    }

    const reduction = Math.min(count, current);
    this.#setCount(contextKey, current - reduction);
  }

  clear(contextKey) {
    if (!contextKey) {
      return;
    }

    this.#setCount(contextKey, 0);
  }

  #setCount(contextKey, newCount) {
    const oldCount = this.#countsByContext.get(contextKey) || 0;

    if (newCount === oldCount) {
      return;
    }

    if (newCount > 0) {
      this.#countsByContext.set(contextKey, newCount);
    } else {
      this.#countsByContext.delete(contextKey);
    }

    const delta = newCount - oldCount;
    this.totalPendingMessageCount = Math.max(
      0,
      this.totalPendingMessageCount + delta
    );
    this.appEvents.trigger("notifications:changed");
  }
}
