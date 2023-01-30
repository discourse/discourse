import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { action } from "@ember/object";

export default Component.extend({
  tagName: "",

  @discourseComputed("model", "model.focused")
  rowClassNames(model, focused) {
    return `chat-channel-selection-row ${focused ? "focused" : ""} ${
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
