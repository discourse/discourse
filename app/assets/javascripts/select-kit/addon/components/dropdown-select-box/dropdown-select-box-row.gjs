import { readOnly } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("dropdown-select-box-row")
export default class DropdownSelectBoxRow extends SelectKitRowComponent {
  @readOnly("item.description") description;

  <template>
    {{#if this.icons}}
      <div class="icons">
        <span class="selection-indicator"></span>
        {{#each this.icons as |i|}}
          {{icon i}}
        {{/each}}
      </div>
    {{/if}}

    <div class="texts">
      <span class="name">{{htmlSafe this.label}}</span>
      {{#if this.description}}
        <span class="desc">{{htmlSafe this.description}}</span>
      {{/if}}
    </div>
  </template>
}
