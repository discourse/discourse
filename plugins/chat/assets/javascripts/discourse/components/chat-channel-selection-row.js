import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",

  isFocused: false,

  @discourseComputed("model", "isFocused")
  rowClassNames(model, isFocused) {
    return `chat-channel-selection-row ${isFocused ? "focused" : ""} ${
      this.model.user ? "user-row" : "channel-row"
    }`;
  },

  @action
  handleClick(event) {
    if (this.onClick) {
      this.onClick(this.model);
      event.preventDefault();
    }
  },
});
