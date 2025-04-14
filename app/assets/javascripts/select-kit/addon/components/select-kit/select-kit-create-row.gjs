import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("create")
export default class SelectKitCreateRow extends SelectKitRowComponent {}

{{#each this.icons as |icon|}}
  {{d-icon icon translatedTitle=this.dasherizedTitle}}
{{/each}}

<span class="name">
  {{this.label}}
</span>