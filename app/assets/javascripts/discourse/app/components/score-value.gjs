import Component from "@glimmer/component";
import { i18n } from "discourse-i18n";

export default class ScoreValue extends Component {
  get numericValue() {
    return parseFloat(Math.abs(this.args.value)).toFixed(1);
  }

  get isNegative() {
    return this.args.value < 0;
  }

  get explanationTitle() {
    return i18n(`review.explain.${this.args.label}.title`);
  }

  get explanationContent() {
    return i18n(`review.explain.${this.args.label}.name`);
  }

  <template>
    {{#if @value}}
      <span class="op">{{if this.isNegative "-" "+"}}</span>
      <span class="score-value">
        <span class="score-number">{{this.numericValue}}</span>
        {{#if @label}}
          <span title={{this.explanationTitle}} class="score-value-type">
            {{this.explanationContent}}
          </span>
        {{/if}}
      </span>
    {{/if}}
  </template>
}
