import Component from "@glimmer/component";
import { service } from "@ember/service";
import emoji from "discourse/helpers/emoji";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { i18n } from "discourse-i18n";

// TODO (glimmer-post-stream) needs tests
export default class PostNoticeNewUser extends Component {
  @service siteSettings;

  get user() {
    return this.siteSettings.display_name_on_posts &&
      prioritizeNameInUx(this.args.post.name)
      ? this.args.post.name
      : this.args.post.username;
  }

  <template>
    {{emoji "tada"}}
    <p>{{i18n "post.notice.new_user" user=this.user}}</p>
  </template>
}
