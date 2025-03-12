import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";

@tagName("li")
export default class UserSummaryUser extends Component {}

<UserInfo @user={{@user}}>
  {{d-icon @icon}}
  <span class={{@countClass}}>{{number @user.count}}</span>
</UserInfo>