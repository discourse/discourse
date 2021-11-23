import Eyeline from "discourse/lib/eyeline";
import Mixin from "@ember/object/mixin";
import Scrolling from "discourse/mixins/scrolling";
import { on } from "discourse-common/utils/decorators";

// Provides the ability to load more items for a view which is scrolled to the bottom.
export default Mixin.create(Scrolling, {
  scrolled() {
    return this.eyeline?.update();
  },

  loadMoreUnlessFull() {
    if (this.screenNotFull()) {
      this.send("loadMore");
    }
  },

  @on("didInsertElement")
  _bindEyeline() {
    const eyeline = Eyeline.create({
      selector: `${this.eyelineSelector}:last`,
    });

    this.set("eyeline", eyeline);
    eyeline.on("sawBottom", () => this.send("loadMore"));
    eyeline.update(); // update once to consider current position

    this.bindScrolling();
  },

  @on("willDestroyElement")
  _removeEyeline() {
    this.unbindScrolling();
  },
});
