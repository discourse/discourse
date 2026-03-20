import Component from "@glimmer/component";
import { service } from "@ember/service";
import autoGroupFlairForUser from "discourse/lib/avatar-flair";
import DAvatarFlair from "discourse/ui-kit/d-avatar-flair";

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

  <template>
    {{#if this.flair}}
      <DAvatarFlair
        @flairName={{this.flair.flairName}}
        @flairUrl={{this.flair.flairUrl}}
        @flairBgColor={{this.flair.flairBgColor}}
        @flairColor={{this.flair.flairColor}}
      />
    {{/if}}
  </template>
}
