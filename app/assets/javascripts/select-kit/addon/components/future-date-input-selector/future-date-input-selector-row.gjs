import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("future-date-input-selector-row")
export default class FutureDateInputSelectorRow extends SelectKitRowComponent {}

{{#if this.item.icon}}
  <div class="future-date-input-selector-icons">
    {{d-icon this.item.icon}}
  </div>
{{/if}}

<span class="name">{{this.label}}</span>

{{#if this.item.timeFormatted}}
  <span class="future-date-input-selector-datetime">
    {{this.item.timeFormatted}}
  </span>
{{/if}}