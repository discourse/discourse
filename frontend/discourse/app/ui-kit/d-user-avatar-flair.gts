import Component from "@glimmer/component";
import { service } from "@ember/service";
import autoGroupFlairForUser, {
  trustLevelGroupFlair,
} from "discourse/lib/avatar-flair";
import type Site from "discourse/models/site";
import DAvatarFlair from "discourse/ui-kit/d-avatar-flair";
import { i18n } from "discourse-i18n";

type SiteSettings = {
  automatically_apply_trust_level_group_flair: boolean;
};

/** The flair attributes of a user, such as a `User` model. */
export interface DUserAvatarFlairUser {
  /** The id of the user. Bot accounts have an id of zero or less. */
  id?: number;

  /** The id of the group whose flair the user shows. */
  flair_group_id?: number | null;

  /** The member's current trust level. */
  trust_level?: number | null;
  trustLevel?: number | null;

  /** The name of the flair group. */
  flair_name?: string | null;

  /** The icon ID or image URL of the flair. */
  flair_url?: string | null;

  /** The background color of the flair. */
  flair_bg_color?: string | null;

  /** The icon color of the flair. */
  flair_color?: string | null;
}

interface DUserAvatarFlairSignature {
  Args: {
    /** The user whose flair is shown. */
    user?: DUserAvatarFlairUser | null;
  };
}

export default class DUserAvatarFlair extends Component<DUserAvatarFlairSignature> {
  @service declare site: Site;
  @service declare siteSettings: SiteSettings;

  get flair() {
    const user = this.args.user;

    if (!user) {
      return;
    }

    if (user.flair_group_id && (user.flair_url || user.flair_bg_color)) {
      return {
        flairName: user.flair_name,
        flairUrl: user.flair_url,
        flairBgColor: user.flair_bg_color,
        flairColor: user.flair_color,
      };
    }

    let autoFlairAttrs;
    if (user.flair_group_id) {
      autoFlairAttrs = autoGroupFlairForUser(this.site, user);
    } else if (
      this.siteSettings.automatically_apply_trust_level_group_flair &&
      !this.isBot
    ) {
      const trustLevel = user.trust_level ?? user.trustLevel;
      if (Number.isInteger(trustLevel)) {
        autoFlairAttrs = trustLevelGroupFlair(this.site, trustLevel);
      }
    }

    if (autoFlairAttrs) {
      return {
        flairName: autoFlairAttrs.flair_name,
        flairUrl: autoFlairAttrs.flair_url,
        flairBgColor: autoFlairAttrs.flair_bg_color,
        flairColor: autoFlairAttrs.flair_color,
      };
    }
  }

  get isBot() {
    const id = this.args.user?.id;
    return Number.isInteger(id) && id! <= 0;
  }

  <template>
    {{#if this.flair}}
      <DAvatarFlair
        @flairBgColor={{this.flair.flairBgColor}}
        @flairColor={{this.flair.flairColor}}
        @flairName={{this.flair.flairName}}
        @flairUrl={{this.flair.flairUrl}}
      />
    {{else if this.isBot}}
      <DAvatarFlair
        aria-label={{i18n "user.bot_account"}}
        class="--bot"
        role="img"
        title={{i18n "user.bot_account"}}
        @flairName="bot"
        @flairUrl="robot"
      />
    {{/if}}
  </template>
}
