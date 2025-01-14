import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import PluginOutlet from "discourse/components/plugin-outlet";
import categoryLink from "discourse/helpers/category-link";
import getURL from "discourse/lib/get-url";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { i18n } from "discourse-i18n";

export default class PostListItemDetails extends Component {
  get titleAriaLabel() {
    return (
      this.args.titleAriaLabel ||
      i18n("post_list.aria_post_number", {
        title: this.args.post.title,
        postNumber: this.args.post.post_number,
      })
    );
  }

  get posterName() {
    if (prioritizeNameInUx(this.args.post.user.name)) {
      return this.args.post.user.name;
    }
    return this.args.post.user.username;
  }

  <template>
    <div class="post-list-item__details">
      <div class="stream-topic-title">
        <span class="title">
          <a
            href={{getURL @post.url}}
            aria-label={{this.titleAriaLabel}}
          >{{htmlSafe @post.topic.fancyTitle}}</a>
        </span>
      </div>

      <div class="stream-post-category">
        {{categoryLink @post.category}}
      </div>

      {{#if @post.user}}
        <div class="post-member-info names">
          <span class="name">{{this.posterName}}</span>

          {{#if @post.user.title}}
            <span class="user-title">{{@post.user.title}}</span>
          {{/if}}

          <PluginOutlet
            @name="post-list-additional-member-info"
            @outletArgs={{hash user=@post.user}}
          />

          {{!
                Deprecated Outlet:
                Please use: "post-list-additional-member-info" instead
              }}
          <PluginOutlet
            @name="group-post-additional-member-info"
            @outletArgs={{hash user=@post.user}}
          />
        </div>
      {{/if}}
    </div>
  </template>
}
