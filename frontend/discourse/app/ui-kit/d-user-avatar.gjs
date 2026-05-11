import Component from "@glimmer/component";
import { service } from "@ember/service";
import DUserLink from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

// TODO (saquetim) the pattern <a>{{avatar ...}}</a> is used a lot. Should we replace it with this component to ensure consistency???
export default class DUserAvatar extends Component {
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
    <DUserLink
      ...attributes
      @ariaHidden={{@ariaHidden}}
      @ariaLabel={{@ariaLabel}}
      @href={{@href}}
      @user={{@user}}
    >
      {{dAvatar
        @user
        extraClasses=(dConcatClass
          @avatarClasses (if this.hideFromAnonUser "non-clickable")
        )
        imageSize=@size
        hideTitle=@hideTitle
        loading=(if @lazy "lazy")
      }}
    </DUserLink>
  </template>
}
