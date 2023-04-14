import Component from "@ember/component";
import KeyEnterEscape from "discourse/mixins/key-enter-escape";
import { schedule } from "@ember/runloop";

export let topicTitleDecorators = [];

export function addTopicTitleDecorator(decorator) {
  topicTitleDecorators.push(decorator);
}

export function resetTopicTitleDecorators() {
  topicTitleDecorators.length = 0;
}

export default Component.extend(KeyEnterEscape, {
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
});
