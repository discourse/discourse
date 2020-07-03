import I18n from "I18n";
import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import discourseComputed from "discourse-common/utils/decorators";
import { getColors } from "../lib/chart-colors";

export default Component.extend({
  tagName: "",

  @discourseComputed("option.votes", "totalVotes")
  percent(votes, total) {
    return I18n.toNumber((votes / total) * 100.0, { precision: 1 });
  },

  @discourseComputed("optionsCount")
  optionColors(optionsCount) {
    return getColors(optionsCount);
  },

  @discourseComputed("optionColors", "index")
  colorStyle(optionColors, index) {
    return htmlSafe(`background: ${optionColors[index]};`);
  }
});
