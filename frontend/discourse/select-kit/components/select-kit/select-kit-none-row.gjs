import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";
import icon from "discourse/ui-kit/helpers/d-icon";

@classNames("none")
export default class SelectKitNoneRow extends SelectKitRowComponent {
  <template>
    {{#each this.icons as |i|}}
      {{icon i translatedTitle=this.dasherizedTitle}}
    {{/each}}

    <span class="name">
      {{this.label}}
    </span>
  </template>
}
