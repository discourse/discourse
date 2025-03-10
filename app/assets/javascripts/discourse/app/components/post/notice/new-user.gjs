import Component from "@glimmer/component";
import { service } from "@ember/service";
import icon from "discourse/helpers/d-icon";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { i18n } from "discourse-i18n";

export default class PostNoticeNewUser extends Component {
  @service siteSettings;

  get user() {
    this.siteSettings.display_name_on_posts &&
    prioritizeNameInUx(this.arg.post.name)
      ? this.arg.post.name
      : this.arg.post.username;
  }

  <template>
    {{icon "handshake-angle"}}
    <p>{{i18n "post.notice.new_user" user=this.user}}</p>
  </template>
}
