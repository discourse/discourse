import Service, { inject as service } from "@ember/service";
import { isTesting } from "discourse-common/config/environment";
import { bind } from "discourse-common/utils/decorators";

export default class ChatMessageVisibilityObserver extends Service {
  @service chat;

  intersectionObserver = new IntersectionObserver(
    this._intersectionObserverCallback,
    {
      root: document,
      rootMargin: "-10px",
    }
  );

  mutationObserver = new MutationObserver(this._mutationObserverCallback, {
    root: document,
    rootMargin: "-10px",
  });

  willDestroy() {
    this.intersectionObserver.disconnect();
    this.mutationObserver.disconnect();
  }

  @bind
  _intersectionObserverCallback(entries) {
    entries.forEach((entry) => {
      entry.target.dataset.visible = entry.isIntersecting;

      if (
        !entry.target.dataset.stagedId &&
        entry.isIntersecting &&
        !isTesting()
      ) {
        this.chat.updateLastReadMessage();
      }
    });
  }

  @bind
  _mutationObserverCallback(mutationList) {
    mutationList.forEach((mutation) => {
      const data = mutation.target.dataset;
      if (data.id && data.visible && !data.stagedId) {
        this.chat.updateLastReadMessage();
      }
    });
  }

  observe(element) {
    this.intersectionObserver.observe(element);
    this.mutationObserver.observe(element, {
      attributes: true,
      attributeOldValue: true,
      attributeFilter: ["data-staged-id"],
    });
  }

  unobserve(element) {
    this.intersectionObserver.unobserve(element);
  }
}
