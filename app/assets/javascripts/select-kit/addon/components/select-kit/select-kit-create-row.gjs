import { classNames } from "@ember-decorators/component";
import icon from "discourse/helpers/d-icon";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("create")
export default class SelectKitCreateRow extends SelectKitRowComponent {
  <template>
    {{#each this.icons as |i|}}
      {{icon i translatedTitle=this.dasherizedTitle}}
    {{/each}}

    <span class="name">
      {{this.label}}
    </span>
  </template>
}
