import I18n from "I18n";
import Component from "@ember/component";
import { action } from "@ember/object";
import { htmlSafe } from "@ember/template";
import discourseComputed from "discourse-common/utils/decorators";
import { getColors } from "../lib/chart-colors";

export default Component.extend({
  tagName: "",
  active: false,

  @discourseComputed("displayMode")
  showPercentage(displayMode) {
    return displayMode === "percentage";
  },

  @discourseComputed("option.votes", "totalVotes")
  percent(votes, total) {
    return I18n.toNumber((votes / total) * 100.0, { precision: 1 });
  },

  @discourseComputed("optionsCount")
  optionColors(optionsCount) {
    return getColors(optionsCount);
  },

  @discourseComputed("active", "optionColors", "index")
  colorBackgroundStyle(active, optionColors, index) {
    if (!this.active) {
      return;
    }

    return htmlSafe(
      `background: ${optionColors[index].replace("1.0", "0.5")};`
    );
  },

  @discourseComputed("optionColors", "index")
  colorPreviewStyle(optionColors, index) {
    return htmlSafe(`background: ${optionColors[index]};`);
  },

  @action
  onHover(active) {
    this.set("active", active);

    if (active) {
      this.onMouseOver();
    } else {
      this.onMouseOut();
    }
  }
});
