import Component from "@glimmer/component";
import { userPath } from "discourse/lib/url";
import { i18n } from "discourse-i18n";

export default class UserLink extends Component {
  get username() {
    return this.args.username || this.args.user?.username;
  }

  get href() {
    return (
      this.args.href ||
      this.args.user?.path ||
      userPath(this.username.toLowerCase())
    );
  }

  get ariaHidden() {
    return this.args.ariaHidden ?? !!this.args.ariaLabel;
  }

  get ariaLabel() {
    return this.args.ariaHidden
      ? null
      : this.args.ariaLabel ??
          i18n("user.profile_possessive", {
            username: this.username,
          });
  }

  <template>
    <a
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
