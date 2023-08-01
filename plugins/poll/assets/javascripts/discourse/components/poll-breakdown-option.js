import { tagName } from "@ember-decorators/component";
import { equal } from "@ember/object/computed";
import Component from "@ember/component";
import I18n from "I18n";
import { action } from "@ember/object";
import discourseComputed from "discourse-common/utils/decorators";
import { getColors } from "discourse/plugins/poll/lib/chart-colors";
import { htmlSafe } from "@ember/template";
import { propertyEqual } from "discourse/lib/computed";

@tagName("")
export default class PollBreakdownOption extends Component {
  // Arguments:
  option = null;
  index = null;
  totalVotes = null;
  optionsCount = null;
  displayMode = null;
  highlightedOption = null;
  onMouseOver = null;
  onMouseOut = null;

  @propertyEqual("highlightedOption", "index") highlighted;
  @equal("displayMode", "percentage") showPercentage;

  @discourseComputed("option.votes", "totalVotes")
  percent(votes, total) {
    return I18n.toNumber((votes / total) * 100.0, { precision: 1 });
  }

  @discourseComputed("optionsCount")
  optionColors(optionsCount) {
    return getColors(optionsCount);
  }

  @discourseComputed("highlighted")
  colorBackgroundStyle(highlighted) {
    if (highlighted) {
      // TODO: Use CSS variables (#10341)
      return htmlSafe("background: rgba(0, 0, 0, 0.1);");
    }
  }

  @discourseComputed("highlighted", "optionColors", "index")
  colorPreviewStyle(highlighted, optionColors, index) {
    const color = highlighted
      ? window.Chart.helpers.getHoverColor(optionColors[index])
      : optionColors[index];

    return htmlSafe(`background: ${color};`);
  }

  @action
  onHover(active) {
    if (active) {
      this.onMouseOver();
    } else {
      this.onMouseOut();
    }
  }
}
