import Component from "@ember/component";
import I18n from "I18n";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { equal } from "@ember/object/computed";
import { getColors } from "discourse/plugins/poll/lib/chart-colors";
import { htmlSafe } from "@ember/template";
import { propertyEqual } from "discourse/lib/computed";

export default Component.extend({
  // Arguments:
  option: null,
  index: null,
  totalVotes: null,
  optionsCount: null,
  displayMode: null,
  highlightedOption: null,
  onMouseOver: null,
  onMouseOut: null,

  tagName: "",

  highlighted: propertyEqual("highlightedOption", "index"),
  showPercentage: equal("displayMode", "percentage"),

  @discourseComputed("option.votes", "totalVotes")
  percent(votes, total) {
    return I18n.toNumber((votes / total) * 100.0, { precision: 1 });
  },

  @discourseComputed("optionsCount")
  optionColors(optionsCount) {
    return getColors(optionsCount);
  },

  @discourseComputed("highlighted")
  colorBackgroundStyle(highlighted) {
    if (highlighted) {
      // TODO: Use CSS variables (#10341)
      return htmlSafe("background: rgba(0, 0, 0, 0.1);");
    }
  },

  @discourseComputed("highlighted", "optionColors", "index")
  colorPreviewStyle(highlighted, optionColors, index) {
    const color = highlighted
      ? window.Chart.helpers.getHoverColor(optionColors[index])
      : optionColors[index];

    return htmlSafe(`background: ${color};`);
  },

  @action
  onHover(active) {
    if (active) {
      this.onMouseOver();
    } else {
      this.onMouseOut();
    }
  },
});
