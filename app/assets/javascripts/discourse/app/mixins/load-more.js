import { on } from "@ember/object/evented";
import Mixin from "@ember/object/mixin";
import { service } from "@ember/service";
import Eyeline from "discourse/lib/eyeline";

// Provides the ability to load more items for a view which is scrolled to the bottom.
export default Mixin.create({
  scrollManager: service(),

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

    this.scrollManager.bindScrolling(this);
  }),

  _removeEyeline: on("willDestroyElement", function () {
    this.scrollManager.unbindScrolling(this);
  }),
});
