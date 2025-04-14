import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("homepage-style-selector-row")
export default class HomepageStyleSelectorRow extends SelectKitRowComponent {}

<div class="texts">
  <span class="name">{{html-safe this.label}}</span>
  {{#if this.item.description}}
    <span class="desc">{{html-safe this.item.description}}</span>
  {{/if}}
</div>