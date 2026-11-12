import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";
import dIcon from "discourse/ui-kit/helpers/d-icon";

@classNames("none")
export default class SelectKitNoneRow extends SelectKitRowComponent {
  <template>
    {{#each this.icons as |i|}}
      {{dIcon i translatedTitle=this.dasherizedTitle}}
    {{/each}}

    <span class="name">
      {{this.label}}
    </span>
  </template>
}
