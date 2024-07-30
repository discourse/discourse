import Component from "@ember/component";
import { getOwner } from "@ember/owner";
import ClickTrack from "discourse/lib/click-track";

export default Component.extend({
  click(event) {
    if (event?.target?.tagName === "A") {
      return ClickTrack.trackClick(event, getOwner(this));
    }
  },
});
