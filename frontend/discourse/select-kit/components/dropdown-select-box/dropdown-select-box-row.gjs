import { computed } from "@ember/object";
import { trustHTML } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@classNames("dropdown-select-box-row")
export default class DropdownSelectBoxRow extends SelectKitRowComponent {
  <template>
    {{#if this.icons}}
      <div class="icons">
        <span class="selection-indicator"></span>
        {{#each this.icons as |i|}}
          {{dIcon i}}
        {{/each}}
      </div>
    {{/if}}

    <div class="texts">
      <span class="name">{{trustHTML this.label}}</span>
      {{#if this.description}}
        <span class="desc">{{trustHTML this.description}}</span>
      {{/if}}
    </div>
  </template>

  @computed("item.description")
  get description() {
    return this.item?.description;
  }
}
