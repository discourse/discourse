import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicStatus from "discourse/components/topic-status";
import categoryLink from "discourse/helpers/category-link";
import getURL from "discourse/lib/get-url";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { i18n } from "discourse-i18n";

export default class PostListItemDetails extends Component {
  get url() {
    return this.args.urlPath
      ? this.args.post[this.args.urlPath]
      : this.args.post?.url;
  }

  get showUserInfo() {
    if (this.args.showUserInfo !== undefined) {
      return this.args.showUserInfo && this.args.user;
    }

    return this.args.user;
  }

  get topicTitle() {
    return this.args?.titlePath
      ? this.args.post[this.args.titlePath]
      : this.args.post?.title;
  }

  get titleAriaLabel() {
    if (this.args.titleAriaLabel) {
      return this.args.titleAriaLabel;
    }

    if (this.args.post.post_number && this.topicTitle) {
      return i18n("post_list.aria_post_number", {
        title: this.topicTitle,
        postNumber: this.args.post.post_number,
      });
    }
  }

  get posterName() {
    if (prioritizeNameInUx(this.args.user.name)) {
      return this.args.user.name;
    }
    return this.args.user.username;
  }

  <template>
    <div class="post-list-item__details">
      <div class="stream-topic-title">
        <TopicStatus @topic={{@post}} @disableActions={{true}} />
        <span class="title">
          {{#if this.url}}
            <a
              href={{getURL this.url}}
              aria-label={{this.titleAriaLabel}}
            >{{this.topicTitle}}</a>
          {{else}}
            {{this.topicTitle}}
          {{/if}}
        </span>
      </div>

      <div class="category stream-post-category">
        {{categoryLink @post.category}}
      </div>

      {{#if this.showUserInfo}}
        <div class="post-member-info names">
          <span class="name">{{this.posterName}}</span>

          {{#if @user.title}}
            <span class="user-title">{{@user.user_title}}</span>
          {{/if}}

          <PluginOutlet
            @name="post-list-additional-member-info"
            @outletArgs={{hash user=@user}}
          />

          {{!
            Deprecated Outlet:
            Please use: "post-list-additional-member-info" instead
          }}
          <PluginOutlet
            @name="group-post-additional-member-info"
            @outletArgs={{hash user=@user}}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
