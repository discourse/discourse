import Component from "@ember/component";
import { schedule } from "@ember/runloop";
import KeyEnterEscape from "discourse/mixins/key-enter-escape";

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

// id like to move this to `components/topic-title`
// _resizeDiscourseMenuPanel = () => this.afterRender();
// window.addEventListener("resize", this._resizeDiscourseMenuPanel);
// window.removeEventListener("resize", this._resizeDiscourseMenuPanel);

// afterRender() {
//   super.afterRender(...arguments);
// const headerTitle = document.querySelector(".header-title .topic-link");
// if (headerTitle && this._topic) {
//   topicTitleDecorators.forEach((cb) =>
//     cb(this._topic, headerTitle, "header-title")
//   );
// }
// this._animateMenu();
// }

// we will need to import `animate` from the header
