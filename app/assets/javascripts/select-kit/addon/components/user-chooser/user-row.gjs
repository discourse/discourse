import { classNames } from "@ember-decorators/component";
import avatar from "discourse/helpers/avatar";
import formatUsername from "discourse/helpers/format-username";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("user-row")
export default class UserRow extends SelectKitRowComponent {
  <template>
    {{avatar this.item imageSize="tiny"}}

    <span class="username">{{formatUsername this.item.username}}</span>

    {{#if this.item.name}}
      <span class="name">{{this.item.name}}</span>
    {{/if}}
  </template>
}
