import Component from "@glimmer/component";
import { service } from "@ember/service";
import UserLink from "discourse/components/user-link";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";

// TODO (saquetim) the pattern <a>{{avatar ...}}</a> is used a lot. Should we replace it with this component to ensure consistency???
export default class UserAvatar extends Component {
  @service currentUser;
  @service siteSettings;

  get ariaHidden() {
    if (this.args.ariaHidden !== null) {
      return this.args.ariaHidden;
    }

    if (this.args.ariaLabel) {
      return false;
    }

    // often avatars are paired with usernames, making them redundant for screen readers so we hide the avatar from
    // screen readers by default
    return this.args.ariaHidden ?? true;
  }

  get hideFromAnonUser() {
    return (
      this.siteSettings.hide_user_profiles_from_public && !this.currentUser
    );
  }

  <template>
    <UserLink
      ...attributes
      @ariaHidden={{@ariaHidden}}
      @ariaLabel={{@ariaLabel}}
      @href={{@href}}
      @user={{@user}}
    >
      {{avatar
        @user
        extraClasses=(concatClass
          @avatarClasses (if this.hideFromAnonUser "non-clickable")
        )
        imageSize=@size
        hideTitle=@hideTitle
        loading=(if @lazy "lazy")
      }}
    </UserLink>
  </template>
}
