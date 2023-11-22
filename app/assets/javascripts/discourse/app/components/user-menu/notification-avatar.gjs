import Component from "@glimmer/component";
import avatar from "discourse/helpers/bound-avatar-template";
import dIcon from "discourse-common/helpers/d-icon";

export default class NotificationAvatar extends Component {
  <template>
    <div class="notification-avatar">
      {{avatar @data.avatarTemplate "small"}}
      {{dIcon @data.icon}}
    </div>
  </template>
}
