import ClickTrack from "discourse/lib/click-track";
import { selectedText } from "discourse/lib/utilities";

export default Ember.Component.extend({
  didInsertElement() {
    this._super();

    this.$().on("mouseup.discourse-redirect", "#revisions a", function(e) {
      // bypass if we are selecting stuff
      const selection = window.getSelection && window.getSelection();
      if (selection.type === "Range" || selection.rangeCount > 0) {
        if (selectedText() !== "") {
          return true;
        }
      }

      const $target = $(e.target);
      if (
        $target.hasClass("mention") ||
        $target.parents(".expanded-embed").length
      ) {
        return false;
      }

      return ClickTrack.trackClick(e);
    });
  },

  willDestroyElement() {
    this._super();
    this.$().off("mouseup.discourse-redirect", "#revisions a");
  }
});
