import { on } from "@ember/object/evented";
import Mixin from "@ember/object/mixin";
import Eyeline from "discourse/lib/eyeline";
import Scrolling from "discourse/mixins/scrolling";

// Provides the ability to load more items for a view which is scrolled to the bottom.
export default Mixin.create(Scrolling, {
  scrolled() {
    return this.eyeline?.update();
  },

  _bindEyeline: on("didInsertElement", function () {
    const eyeline = Eyeline.create({
      selector: `${this.eyelineSelector}:last`,
    });

    this.set("eyeline", eyeline);
    eyeline.on("sawBottom", () => this.send("loadMore"));
    eyeline.update(); // update once to consider current position

    this.bindScrolling();
  }),

  _removeEyeline: on("willDestroyElement", function () {
    this.unbindScrolling();
  }),
});
