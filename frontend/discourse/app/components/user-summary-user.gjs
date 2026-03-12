/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import UserInfo from "discourse/ui-kit/d-user-info";
import icon from "discourse/ui-kit/helpers/d-icon";
import number from "discourse/ui-kit/helpers/d-number";

@tagName("")
export default class UserSummaryUser extends Component {
  <template>
    <li ...attributes>
      <UserInfo @user={{@user}}>
        {{icon @icon}}
        <span class={{@countClass}}>{{number @user.count}}</span>
      </UserInfo>
    </li>
  </template>
}
