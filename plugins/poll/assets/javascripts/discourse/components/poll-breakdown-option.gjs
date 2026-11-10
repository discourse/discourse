import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { trustHTML } from "@ember/template";
import { loadChartJSGetHoverColor } from "discourse/lib/load-chart-js";
import { deepEqual } from "discourse/lib/object";
import I18n, { i18n } from "discourse-i18n";
import { getColors } from "discourse/plugins/poll/lib/chart-colors";
import decoratePollOption from "../modifiers/decorate-poll-option.js";

export default class PollBreakdownOption extends Component {
  @tracked getHoverColor;

  constructor() {
    super(...arguments);
    loadChartJSGetHoverColor().then((getHoverColor) => {
      this.getHoverColor = getHoverColor;
    });
  }

  get highlighted() {
    return deepEqual(this.args.highlightedOption, this.args.index);
  }

  get showPercentage() {
    return this.args.displayMode === "percentage";
  }

  get percent() {
    return I18n.toNumber(
      (this.args.option?.votes / this.args.totalVotes) * 100.0,
      {
        precision: 1,
      }
    );
  }

  get optionColors() {
    return getColors(this.args.optionsCount);
  }

  get colorBackgroundStyle() {
    if (this.highlighted) {
      // TODO: Use CSS variables (#10341)
      return trustHTML("background: rgba(0, 0, 0, 0.1);");
    }
  }

  get colorPreviewStyle() {
    const color = this.optionColors[this.args.index];
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
