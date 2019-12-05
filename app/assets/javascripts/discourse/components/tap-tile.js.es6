import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  classNames: ["tap-tile"],
  classNameBindings: ["active"],
  click: function() {
    this.onSelect(this.tileId);
  },

  @discourseComputed("activeTile", "tileId")
  active(activeTile, tileId) {
    return activeTile === tileId;
  }
});
