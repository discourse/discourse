import Helper from "@ember/component/helper";
import { service } from "discourse/lib/service";
import ScrollStateService from "discourse/services/scroll-state";

const VALID_DIRECTIONS = ["above", "below"];

export default class HideScrollableContent extends Helper {
  @service(() => ScrollStateService) scrollState;

  #registered = false;

  compute([direction]) {
    if (!this.#registered) {
      if (!VALID_DIRECTIONS.includes(direction)) {
        throw new Error(
          `{{hideScrollableContent}}: invalid direction "${direction}", expected "above" or "below"`
        );
      }

      if (direction === "above") {
        this.scrollState.hideScrollableContentAbove(this);
      } else {
        this.scrollState.hideScrollableContentBelow(this);
      }
      this.#registered = true;
    }
  }
}
