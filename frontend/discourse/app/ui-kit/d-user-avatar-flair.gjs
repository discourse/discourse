import Component from "@glimmer/component";
import { service } from "@ember/service";
import autoGroupFlairForUser from "discourse/lib/avatar-flair";
import DAvatarFlair from "discourse/ui-kit/d-avatar-flair";
import { i18n } from "discourse-i18n";

export default class DUserAvatarFlair extends Component {
  @service site;

  get flair() {
    const user = this.args.user;

    if (!user || !user.flair_group_id) {
      return;
    }

    if (user.flair_url || user.flair_bg_color) {
      return {
        flairName: user.flair_name,
        flairUrl: user.flair_url,
        flairBgColor: user.flair_bg_color,
        flairColor: user.flair_color,
      };
    }

    const autoFlairAttrs = autoGroupFlairForUser(this.site, user);
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
    return Number.isInteger(id) && id <= 0;
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
