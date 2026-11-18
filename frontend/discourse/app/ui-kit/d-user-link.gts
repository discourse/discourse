import Component from "@glimmer/component";
import { service } from "@ember/service";
import { userPath } from "discourse/lib/url";
import type User from "discourse/models/user";
import { i18n } from "discourse-i18n";

/** The site settings this component reads. */
type SiteSettings = {
  hide_user_profiles_from_public: boolean;
};

/** A user the link points to, such as a `User` model. */
export interface DUserLinkUser {
  /** The username, which also names the user card. */
  username?: string;

  /** The path of the user's profile. */
  path?: string;
}

interface DUserLinkSignature {
  Args: {
    /** The username to link to. It takes precedence over `@user`. */
    username?: string;

    /** The user to link to. */
    user?: DUserLinkUser | null;

    /** The URL to link to, in place of the user's profile. */
    href?: string;

    /** Whether to hide the link from assistive technology and the tab order. */
    ariaHidden?: boolean;

    /** The accessible name of the link. Defaults to the user's profile. */
    ariaLabel?: string;
  };

  Element: HTMLAnchorElement;

  Blocks: {
    /** The link content. */
    default: [];
  };
}

export default class DUserLink extends Component<DUserLinkSignature> {
  @service declare currentUser: User | null;
  @service declare siteSettings: SiteSettings;

  get username() {
    return this.args.username || this.args.user?.username;
  }

  get hideFromAnonUser() {
    return (
      this.siteSettings.hide_user_profiles_from_public && !this.currentUser
    );
  }

  get href() {
    if (this.hideFromAnonUser) {
      return null;
    }

    const url = this.args.href || this.args.user?.path;
    if (url) {
      return url;
    }

    if (this.username) {
      return userPath(this.username.toLowerCase());
    }
  }

  get ariaHidden() {
    return this.args.ariaHidden === true ? "true" : undefined;
  }

  get ariaLabel() {
    if (this.args.ariaHidden === true) {
      return;
    }

    if (this.args.ariaLabel) {
      return this.args.ariaLabel;
    }

    if (this.username) {
      return i18n("user.profile_possessive", {
        username: this.username,
      });
    }
  }

  <template>
    <a
      class={{if this.hideFromAnonUser "non-clickable"}}
      ...attributes
      aria-hidden={{this.ariaHidden}}
      aria-label={{this.ariaLabel}}
      data-user-card={{this.username}}
      href={{this.href}}
      tabindex={{if this.ariaHidden "-1" "0"}}
    >
      {{yield}}
    </a>
  </template>
}
