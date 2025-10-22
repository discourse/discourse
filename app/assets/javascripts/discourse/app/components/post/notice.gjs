import Component from "@glimmer/component";
import { dasherize } from "@ember/string";
import concatClass from "discourse/helpers/concat-class";
import { applyValueTransformer } from "discourse/lib/transformer";
import PostNoticeCustom from "./notice/custom";
import PostNoticeNewUser from "./notice/new-user";
import PostNoticeReturningUser from "./notice/returning-user";

const POST_NOTICE_COMPONENTS = {
  custom: PostNoticeCustom,
  new_user: PostNoticeNewUser,
  returning_user: PostNoticeReturningUser,
};

export default class PostNotice extends Component {
  static shouldRender(post, siteSettings) {
    if (!post.notice || post.deletedAt) {
      return false;
    }

    const postAge = new Date() - new Date(post.created_at);
    const maxAge = siteSettings.old_post_notice_days * 86400000;

    return post.notice.type === "custom" || postAge <= maxAge;
  }

  get Component() {
    return applyValueTransformer(
      "post-notice-component",
      POST_NOTICE_COMPONENTS[this.type],
      { type: this.type, post: this.args.post }
    );
  }

  get type() {
    return this.args.post.notice.type;
  }

  <template>
    <div class={{concatClass "post-notice" (dasherize this.type)}}>
      <this.Component @notice={{@post.notice}} @post={{@post}} />
    </div>
  </template>
}
