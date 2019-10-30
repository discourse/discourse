import { scheduleOnce } from "@ember/runloop";
import { on, observes } from "ember-addons/ember-computed-decorators";
import autosize from "discourse/lib/autosize";

export default Ember.TextArea.extend({
  @on("didInsertElement")
  _startWatching() {
    scheduleOnce("afterRender", () => {
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
