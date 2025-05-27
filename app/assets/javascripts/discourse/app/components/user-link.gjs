import Component from "@glimmer/component";
import { service } from "@ember/service";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class UserLink extends Component {
  @service currentUser;
  @service siteSettings;

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
    return this.args.ariaHidden ?? !!this.args.ariaLabel;
  }

  get ariaLabel() {
    if (this.args.ariaHidden) {
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
      href={{this.href}}
      data-user-card={{this.username}}
      aria-hidden={{this.ariaHidden}}
      aria-label={{this.ariaLabel}}
    >
      {{yield}}
    </a>
  </template>
}
