import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicStatus from "discourse/components/topic-status";
import categoryLink from "discourse/helpers/category-link";
import { prioritizeNameInUx } from "discourse/lib/settings";
import getURL from "discourse-common/lib/get-url";
import { i18n } from "discourse-i18n";

export default class PostListItemDetails extends Component {
  @tracked url = this.args.post?.url || this.args.post?.post_url;

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
        <TopicStatus @topic={{@post}} @disableActions={{true}} />
        <span class="title">
          {{log this.url}}
          {{#if this.url}}
            <a
              href={{getURL this.url}}
              aria-label={{this.titleAriaLabel}}
            >{{htmlSafe this.topicTitle}}</a>
          {{else}}
            {{htmlSafe this.topicTitle}}
          {{/if}}
        </span>
      </div>

      <div class="category stream-post-category">
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
