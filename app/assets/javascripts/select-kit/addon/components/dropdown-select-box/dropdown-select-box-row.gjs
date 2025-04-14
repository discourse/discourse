import { readOnly } from "@ember/object/computed";
import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("dropdown-select-box-row")
export default class DropdownSelectBoxRow extends SelectKitRowComponent {
  @readOnly("item.description") description;
}

{{#if this.icons}}
  <div class="icons">
    <span class="selection-indicator"></span>
    {{#each this.icons as |icon|}}
      {{d-icon icon}}
    {{/each}}
  </div>
{{/if}}

<div class="texts">
  <span class="name">{{html-safe this.label}}</span>
  {{#if this.description}}
    <span class="desc">{{html-safe this.description}}</span>
  {{/if}}
</div>