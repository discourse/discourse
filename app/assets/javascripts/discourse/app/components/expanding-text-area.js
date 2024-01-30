import { TextArea } from "@ember/legacy-built-in-components";
import { schedule } from "@ember/runloop";
import $ from "jquery";
import autosize from "discourse/lib/autosize";
import { observes, on } from "discourse-common/utils/decorators";

export default TextArea.extend({
  @on("didInsertElement")
  _startWatching() {
    schedule("afterRender", () => {
      $(this.element).focus();
      autosize(this.element);
    });
  },

  @observes("value")
  _updateAutosize() {
    this.element.value = this.value;
    const event = new Event("autosize:update", {
      bubbles: true,
      cancelable: false,
    });
    this.element.dispatchEvent(event);
  },

  @on("willDestroyElement")
  _disableAutosize() {
    autosize.destroy($(this.element));
  },
});
