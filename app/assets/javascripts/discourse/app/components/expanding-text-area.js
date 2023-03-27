import { observes, on } from "discourse-common/utils/decorators";
import { TextArea } from "@ember/legacy-built-in-components";
import autosize from "discourse/lib/autosize";
import { schedule } from "@ember/runloop";

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
    const evt = document.createEvent("Event");
    evt.initEvent("autosize:update", true, false);
    this.element.dispatchEvent(evt);
  },

  @on("willDestroyElement")
  _disableAutosize() {
    autosize.destroy($(this.element));
  },
});
