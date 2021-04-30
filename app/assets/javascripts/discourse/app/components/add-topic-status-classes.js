import Component from "@ember/component";
import { observes } from "discourse-common/utils/decorators";
import { scheduleOnce } from "@ember/runloop";

export default Component.extend({
  didInsertElement() {
    this._super(...arguments);
    this.refreshClass();
  },

  _updateClass() {
    if (this.isDestroying || this.isDestroyed) {
      return;
    }
    const topic = this.topic;

    this._removeClass();

    let classes = [];
    if (topic.invisible) {
      classes.push(`topic-status-unlisted`);
    }
    if (topic.pinned) {
      classes.push("topic-status-pinned");
    }
    if (topic.unpinned) {
      classes.push("topic-status-unpinned");
    }
    if (classes.length > 0) {
      $("body").addClass(classes.join(" "));
    }
  },

  @observes("topic.invisible", "topic.pinned", "topic.unpinned")
  refreshClass() {
    scheduleOnce("afterRender", this, this._updateClass);
  },

  _removeClass() {
    $("body").removeClass((_, css) =>
      (css.match(/\btopic-status-\S+/g) || []).join(" ")
    );
  },

  willDestroyElement() {
    this._super(...arguments);
    this._removeClass();
  },
});
