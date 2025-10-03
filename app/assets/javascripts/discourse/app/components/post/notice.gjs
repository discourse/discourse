import Component from "@glimmer/component";
import { service } from "@ember/service";
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
  @service siteSettings;

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

  get shouldRender() {
    const postAge = new Date() - new Date(this.args.post.created_at);
    const maxAge = this.siteSettings.old_post_notice_days * 86400000;
    return this.args.post.notice.type === "custom" || postAge <= maxAge;
  }

  <template>
    {{#if this.shouldRender}}
      <div class={{concatClass "post-notice" (dasherize this.type)}}>
        <this.Component @notice={{@post.notice}} @post={{@post}} />
      </div>
    {{/if}}
  </template>
}
