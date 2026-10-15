/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { on } from "@ember/modifier";
import { computed } from "@ember/object";
import { trustHTML } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import { loadChartJSGetHoverColor } from "discourse/lib/load-chart-js";
import { deepEqual } from "discourse/lib/object";
import I18n, { i18n } from "discourse-i18n";
import { getColors } from "discourse/plugins/poll/lib/chart-colors";
import decoratePollOption from "../modifiers/decorate-poll-option.js";

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

  constructor() {
    super(...arguments);
    loadChartJSGetHoverColor().then((getHoverColor) => {
      this.set("getHoverColor", getHoverColor);
    });
  }

  @computed("highlightedOption", "index")
  get highlighted() {
    return deepEqual(this.highlightedOption, this.index);
  }

  @computed("displayMode")
  get showPercentage() {
    return this.displayMode === "percentage";
  }

  @computed("option.votes", "totalVotes")
  get percent() {
    return I18n.toNumber((this.option?.votes / this.totalVotes) * 100.0, {
      precision: 1,
    });
  }

  @computed("optionsCount")
  get optionColors() {
    return getColors(this.optionsCount);
  }

  @computed("highlighted")
  get colorBackgroundStyle() {
    if (this.highlighted) {
      // TODO: Use CSS variables (#10341)
      return trustHTML("background: rgba(0, 0, 0, 0.1);");
    }
  }

  @computed("getHoverColor", "highlighted", "optionColors", "index")
  get colorPreviewStyle() {
    const color = this.optionColors[this.index];
    const previewColor = this.highlighted
      ? (this.getHoverColor?.(color) ?? color)
      : color;

    return trustHTML(`background: ${previewColor};`);
  }

  <template>
    <li
      class="poll-breakdown-option"
      role="button"
      style={{this.colorBackgroundStyle}}
      {{on "mouseover" @onMouseOver}}
      {{on "mouseout" @onMouseOut}}
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
