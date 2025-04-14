import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("none")
export default class SelectKitNoneRow extends SelectKitRowComponent {}

{{#each this.icons as |icon|}}
  {{d-icon icon translatedTitle=this.dasherizedTitle}}
{{/each}}

<span class="name">
  {{this.label}}
</span>