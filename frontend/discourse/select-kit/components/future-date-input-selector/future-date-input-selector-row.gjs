import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@classNames("future-date-input-selector-row")
export default class FutureDateInputSelectorRow extends SelectKitRowComponent {
  <template>
    {{#if this.item.icon}}
      <div class="future-date-input-selector-icons">
        {{dIcon this.item.icon}}
      </div>
    {{/if}}

    <span class="name">{{this.label}}</span>

    {{#if this.item.timeFormatted}}
      <span class="future-date-input-selector-datetime">
        {{this.item.timeFormatted}}
      </span>
    {{/if}}
  </template>
}
