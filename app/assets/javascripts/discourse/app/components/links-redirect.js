import { getOwner } from "@ember/application";
import Component from "@ember/component";
import ClickTrack from "discourse/lib/click-track";

export default Component.extend({
  click(event) {
    if (event?.target?.tagName === "A") {
      return ClickTrack.trackClick(event, getOwner(this));
    }
  },
});
