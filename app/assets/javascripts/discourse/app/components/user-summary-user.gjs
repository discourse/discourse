import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import UserInfo from "discourse/components/user-info";
import icon from "discourse/helpers/d-icon";
import number from "discourse/helpers/number";

@tagName("li")
export default class UserSummaryUser extends Component {
  <template>
    <UserInfo @user={{@user}}>
      {{icon @icon}}
      <span class={{@countClass}}>{{number @user.count}}</span>
    </UserInfo>
  </template>
}
