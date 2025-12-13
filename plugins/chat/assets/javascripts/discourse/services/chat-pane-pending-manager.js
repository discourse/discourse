import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";

export default class ChatPanePendingManager extends Service {
  @service appEvents;

  @tracked totalPending = 0;
  #contextTotals = new Map();

  increment(key, count = 1) {
    if (!key || count <= 0) {
      return;
    }

    const current = this.#contextTotals.get(key) || 0;
    this.#contextTotals.set(key, current + count);
    this.#updateTotal(count);
  }

  decrement(key, count = 1) {
    if (!key || count <= 0) {
      return;
    }

    const current = this.#contextTotals.get(key);
    if (!current) {
      return;
    }

    const reduction = Math.min(count, current);
    const next = current - reduction;

    if (next) {
      this.#contextTotals.set(key, next);
    } else {
      this.#contextTotals.delete(key);
    }

    this.#updateTotal(-reduction);
  }

  clear(key) {
    if (!key) {
      return;
    }

    const current = this.#contextTotals.get(key);
    if (!current) {
      return;
    }

    this.#contextTotals.delete(key);
    this.#updateTotal(-current);
  }

  #updateTotal(delta) {
    if (!delta) {
      return;
    }

    this.totalPending = Math.max(0, this.totalPending + delta);
    this.appEvents.trigger("notifications:changed");
  }
}
