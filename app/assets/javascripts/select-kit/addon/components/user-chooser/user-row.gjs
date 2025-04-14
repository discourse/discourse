import { classNames } from "@ember-decorators/component";
import SelectKitRowComponent from "select-kit/components/select-kit/select-kit-row";

@classNames("user-row")
export default class UserRow extends SelectKitRowComponent {}

{{avatar this.item imageSize="tiny"}}

<span class="username">{{format-username this.item.username}}</span>

{{#if this.item.name}}
  <span class="name">{{this.item.name}}</span>
{{/if}}