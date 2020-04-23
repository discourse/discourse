import TextArea from "@ember/component/text-area";
import { schedule } from "@ember/runloop";
import { on, observes } from "discourse-common/utils/decorators";
import autosize from "discourse/lib/autosize";

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
  }
});
