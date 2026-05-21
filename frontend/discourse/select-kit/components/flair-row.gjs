import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";
import DAvatarFlair from "discourse/ui-kit/d-avatar-flair";

@classNames("flair-row")
export default class FlairRow extends SelectKitRowComponent {
  <template>
    {{#if this.item.url}}
      <DAvatarFlair
        @flairName={{this.item.name}}
        @flairUrl={{this.item.url}}
        @flairBgColor={{this.item.bgColor}}
        @flairColor={{this.item.color}}
      />
    {{/if}}

    <span>{{this.label}}</span>
  </template>
}
