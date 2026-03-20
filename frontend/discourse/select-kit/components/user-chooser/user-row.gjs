import { classNames } from "@ember-decorators/component";
import formatUsername from "discourse/helpers/format-username";
import SelectKitRowComponent from "discourse/select-kit/components/select-kit/select-kit-row";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";

@classNames("user-row")
export default class UserRow extends SelectKitRowComponent {
  <template>
    {{dAvatar this.item imageSize="tiny"}}

    <span class="username">{{formatUsername this.item.username}}</span>

    {{#if this.item.name}}
      <span class="name">{{this.item.name}}</span>
    {{/if}}
  </template>
}
