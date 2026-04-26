import { trustHTML } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";

@classNames("homepage-style-selector-row")
export default class HomepageStyleSelectorRow extends SelectKitRowComponent {
  <template>
    <div class="texts">
      <span class="name">{{trustHTML this.label}}</span>
      {{#if this.item.description}}
        <span class="desc">{{trustHTML this.item.description}}</span>
      {{/if}}
    </div>
  </template>
}
