import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import categoryLink from "discourse/helpers/category-link";
import { prioritizeNameInUx } from "discourse/lib/settings";
import getURL from "discourse-common/lib/get-url";
import { i18n } from "discourse-i18n";

export default class PostListItemDetails extends Component {
  get topicTitle() {
    return this.args.post?.topic_html_title || this.args.post?.topic_title;
  }

  get titleAriaLabel() {
    return (
      this.args.titleAriaLabel ||
      i18n("post_list.aria_post_number", {
        title: this.args.post.topic_title,
        postNumber: this.args.post.post_number,
      })
    );
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
        <span class="title">
          <a
            href={{getURL @post.url}}
            aria-label={{this.titleAriaLabel}}
          >{{htmlSafe this.topicTitle}}</a>
        </span>
      </div>

      <div class="stream-post-category">
        {{categoryLink @post.category}}
      </div>

      {{#if @user}}
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
