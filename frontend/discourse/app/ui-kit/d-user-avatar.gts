import Component from "@glimmer/component";
import { service } from "@ember/service";
import type User from "discourse/models/user";
import DUserLink, { type DUserLinkUser } from "discourse/ui-kit/d-user-link";
import dAvatar from "discourse/ui-kit/helpers/d-avatar";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

/** The site settings this component reads. */
type SiteSettings = {
  hide_user_profiles_from_public: boolean;
};

/** The user whose avatar is shown, such as a `User` model. */
export interface DUserAvatarUser extends DUserLinkUser {
  /** The template of the avatar URL. */
  avatar_template?: string;

  /** The name of the user, shown in the avatar's title. */
  name?: string | null;
}

interface DUserAvatarSignature {
  Args: {
    /** The user whose avatar is shown and linked. */
    user?: DUserAvatarUser | null;

    /** The size of the avatar, such as `medium`. */
    size?: string;

    /** Whether to omit the avatar's title. */
    hideTitle?: boolean;

    /** Whether to load the avatar lazily. */
    lazy?: boolean;

    /** Classes added to the avatar image. */
    avatarClasses?: string;

    /** The URL to link to, in place of the user's profile. */
    href?: string;

    /**
     * Whether to hide the link from assistive technology. Defaults to `true`, unless
     * `@ariaLabel` is given, because an avatar usually sits next to the username.
     */
    ariaHidden?: boolean;

    /** The accessible name of the link. */
    ariaLabel?: string;
  };

  Element: HTMLAnchorElement;
}

// TODO (saquetim) the pattern <a>{{avatar ...}}</a> is used a lot. Should we replace it with this component to ensure consistency???
export default class DUserAvatar extends Component<DUserAvatarSignature> {
  @service declare currentUser: User | null;
  @service declare siteSettings: SiteSettings;

  get ariaHidden() {
    if (this.args.ariaHidden != null) {
      return this.args.ariaHidden;
    }

    if (this.args.ariaLabel) {
      return false;
    }

    // often avatars are paired with usernames, making them redundant for screen readers so we hide the avatar from
    // screen readers by default
    return true;
  }

  get hideFromAnonUser() {
    return (
      this.siteSettings.hide_user_profiles_from_public && !this.currentUser
    );
  }

  <template>
    <DUserLink
      ...attributes
      @ariaHidden={{this.ariaHidden}}
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
