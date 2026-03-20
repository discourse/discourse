import { tagName } from "@ember-decorators/component";
import SelectedNameComponent from "discourse/select-kit/components/selected-name";
import DAvatarFlair from "discourse/ui-kit/d-avatar-flair";

@tagName("")
export default class SelectedFlair extends SelectedNameComponent {
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
