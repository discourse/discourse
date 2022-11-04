import Service, { inject as service } from "@ember/service";
import { isTesting } from "discourse-common/config/environment";
import { bind } from "discourse-common/utils/decorators";

export default class ChatMessageVisibilityObserver extends Service {
  @service chat;

  observer = new IntersectionObserver(this._observerCallback, {
    root: document,
    rootMargin: "-10px",
  });

  willDestroy() {
    this.observer.disconnect();
  }

  @bind
  _observerCallback(entries) {
    entries.forEach((entry) => {
      entry.target.dataset.visible = entry.isIntersecting;

      if (entry.isIntersecting && !isTesting()) {
        this.chat.updateLastReadMessage();
      }
    });
  }

  observe(element) {
    this.observer.observe(element);
  }

  unobserve(element) {
    this.observer.unobserve(element);
  }
}
