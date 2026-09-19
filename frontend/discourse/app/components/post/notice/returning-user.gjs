import { relativeAgeMediumSpan } from "discourse/lib/formatter";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import { i18n } from "discourse-i18n";
import PostNoticeNewUser from "./new-user";

export default class PostNoticeReturningUser extends PostNoticeNewUser {
  get time() {
    const timeAgo =
      (new Date() - new Date(this.args.notice.last_posted_at)) / 1000;
    return relativeAgeMediumSpan(timeAgo, true);
  }

  <template>
    {{dEmoji "wave"}}
    <p>{{i18n "post.notice.returning_user" user=this.user time=this.time}}</p>
  </template>
}
