import Component from "@glimmer/component";
import { service } from "discourse/lib/service";
import { prioritizeNameInUx } from "discourse/lib/settings";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import { i18n } from "discourse-i18n";
import SiteSettingsService from "discourse/services/site-settings";

export default class PostNoticeNewUser extends Component {
  @service(() => SiteSettingsService) siteSettings;

  get user() {
    return this.siteSettings.display_name_on_posts &&
      prioritizeNameInUx(this.args.post.name)
      ? this.args.post.name
      : this.args.post.username;
  }

  <template>
    {{dEmoji "tada"}}
    <p>{{i18n "post.notice.new_user" user=this.user}}</p>
  </template>
}
