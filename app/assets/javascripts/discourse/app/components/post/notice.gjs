import Component from "@glimmer/component";
import { get } from "@ember/helper";
import { service } from "@ember/service";
import { dasherize } from "@ember/string";
import concatClass from "discourse/helpers/concat-class";
import { applyValueTransformer } from "discourse/lib/transformer";
import PostNoticeCustom from "./notice/custom";
import PostNoticeNewUser from "./notice/new-user";
import PostNoticeReturningUser from "./notice/returning-user";

export default class PostNotice extends Component {
  @service siteSettings;

  get components() {
    return applyValueTransformer("post-notice-components", {
      custom: PostNoticeCustom,
      new_user: PostNoticeNewUser,
      returning_user: PostNoticeReturningUser,
    });
  }

  get classNames() {
    const classes = [dasherize(this.args.post.notice.type)];

    if (
      new Date() - new Date(this.args.post.created_at) >
      this.siteSettings.old_post_notice_days * 86400000
    ) {
      classes.push("old");
    }

    return classes;
  }

  get type() {
    return this.args.post.notice.type;
  }

  <template>
    <div class={{concatClass "post-notice" this.classNames}}>
      {{#let (get this.components this.type) as |PostNoticeTypeComponent|}}
        <PostNoticeTypeComponent @notice={{@post.notice}} @post={{@post}} />
      {{/let}}
    </div>
  </template>
}
