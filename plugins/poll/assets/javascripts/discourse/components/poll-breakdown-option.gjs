/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { on } from "@ember/modifier";
import { computed } from "@ember/object";
import { equal } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import { propertyEqual } from "discourse/lib/computed";
import loadChartJS from "discourse/lib/load-chart-js";
import I18n, { i18n } from "discourse-i18n";
import { getColors } from "discourse/plugins/poll/lib/chart-colors";
import decoratePollOption from "../modifiers/decorate-poll-option";

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

  constructor() {
    super(...arguments);
    loadChartJS().then((Chart) => {
      this.set("Chart", Chart);
    });
  }

  @computed("option.votes", "totalVotes")
  get percent() {
    return I18n.toNumber((this.option?.votes / this.totalVotes) * 100.0, { precision: 1 });
  }

  @computed("optionsCount")
  get optionColors() {
    return getColors(this.optionsCount);
  }

  @computed("highlighted")
  get colorBackgroundStyle() {
    if (this.highlighted) {
      // TODO: Use CSS variables (#10341)
      return htmlSafe("background: rgba(0, 0, 0, 0.1);");
    }
  }

  @computed("Chart", "highlighted", "optionColors", "index")
  get colorPreviewStyle() {
    const color = this.highlighted
      ? this.Chart?.helpers.getHoverColor(this.optionColors[this.index])
      : this.optionColors[this.index];

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
      <span
        class="poll-breakdown-option-text"
        {{decoratePollOption @option.html}}
      ></span>
    </li>
  </template>
}
