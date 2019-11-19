import Component from "@ember/component";
import KeyEnterEscape from "discourse/mixins/key-enter-escape";

export default Component.extend(KeyEnterEscape, {
  elementId: "topic-title"
});
