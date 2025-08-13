import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import UserLink from "discourse/components/user-link";
import { avatarImg } from "discourse/lib/avatar-utils";
import { userPath } from "discourse/lib/url";

export default class LikedUserItem extends Component {
  get avatarImage() {
    return htmlSafe(
      avatarImg({
        avatarTemplate: this.args.user.avatar_template,
        size: "small",
        title: this.args.user.name,
      })
    );
  }

  get userUrl() {
    return userPath(this.args.user.username);
  }

  <template>
    <UserLink
      @username={{@user.username}}
      @href={{this.userUrl}}
      title={{@user.username}}
      class="poster trigger-user-card"
      data-user-card={{@user.username}}
    >
      {{this.avatarImage}}
    </UserLink>
  </template>
}
