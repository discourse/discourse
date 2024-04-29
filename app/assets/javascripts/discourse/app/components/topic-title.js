import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import { isiPad } from "discourse/lib/utilities";

export let topicTitleDecorators = [];

export function addTopicTitleDecorator(decorator) {
  topicTitleDecorators.push(decorator);
}

export function resetTopicTitleDecorators() {
  topicTitleDecorators.length = 0;
}

export default Component.extend({
  elementId: "topic-title",

  didInsertElement() {
    this._super(...arguments);

    schedule("afterRender", () => {
      if (this.element && !this.isDestroying && !this.isDestroyed) {
        const fancyTitle = this.element.querySelector(".fancy-title");

        fancyTitle &&
          topicTitleDecorators &&
          topicTitleDecorators.forEach((cb) =>
            cb(this.model, fancyTitle, "topic-title")
          );
      }
    });
  },

  keyDown(e) {
    if (document.body.classList.contains("modal-open")) {
      return;
    }

    if (e.key === "Escape") {
      e.preventDefault();
      this.cancelled();
    } else if (
      e.key === "Enter" &&
      (e.ctrlKey || e.metaKey || (isiPad() && e.altKey))
    ) {
      // Ctrl+Enter or Cmd+Enter
      // iPad physical keyboard does not offer Command or Ctrl detection
      // so use Alt+Enter
      e.preventDefault();
      this.save(undefined, e);
    }
  },
});
