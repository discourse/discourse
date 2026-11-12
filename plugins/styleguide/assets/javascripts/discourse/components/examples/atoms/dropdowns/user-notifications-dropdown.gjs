import Component from "@glimmer/component";
import { service } from "@ember/service";
import UserNotificationsDropdown from "discourse/select-kit/components/user-notifications-dropdown";

export default class UserNotificationsDropdownExample extends Component {
  @service currentUser;

  <template>
    <UserNotificationsDropdown
      @user={{this.currentUser}}
      @value="changeToNormal"
    />
  </template>
}
