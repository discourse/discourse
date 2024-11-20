import Component from "@ember/component";
import { on } from "@ember/modifier";
import { equal } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import { propertyEqual } from "discourse/lib/computed";
import discourseComputed from "discourse-common/utils/decorators";
import I18n, { i18n } from "discourse-i18n";
import { getColors } from "discourse/plugins/poll/lib/chart-colors";

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

  <template>
    <li
      class="poll-breakdown-option"
      style={{this.colorBackgroundStyle}}
      {{on "mouseover" @onMouseOver}}
      {{on "mouseout" @onMouseOut}}
      role="button"
    >
      <span
        class="poll-breakdown-option-color"
        style={{this.colorPreviewStyle}}
      ></span>

      <span class="poll-breakdown-option-count">
        {{#if this.showPercentage}}
          {{i18n "number.percent" count=this.percent}}
        {{else}}
          {{@option.votes}}
        {{/if}}
      </span>
      <span class="poll-breakdown-option-text">{{htmlSafe @option.html}}</span>
    </li>
  </template>
}
