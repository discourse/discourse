import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import ExpandPost from "discourse/components/expand-post";
import PostListItemDetails from "discourse/components/post-list/item/details";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import formatDate from "discourse/helpers/format-date";
import { userPath } from "discourse/lib/url";

export default class PostListItem extends Component {
  @service site;

  get moderatorActionClass() {
    return this.args.post.post_type === this.site.post_types.moderator_action
      ? "moderator-action"
      : "";
  }

  get primaryGroupClass() {
    if (this.args.post.user && this.args.post.user.primary_group_name) {
      return `group-${this.args.post.user.primary_group_name}`;
    }
  }

  <template>
    <div
      class="post-list-item
        {{concatClass
          this.moderatorActionClass
          this.primaryGroupClass
          @additionalItemClasses
        }}"
    >
      <div class="post-list-item__header info">
        <a
          href={{userPath @post.user.username}}
          data-user-card={{@post.user.username}}
          class="avatar-link"
        >
          {{avatar
            @post.user
            imageSize="large"
            extraClasses="actor"
            ignoreTitle="true"
          }}
        </a>

        <PostListItemDetails
          @post={{@post}}
          @titleAriaLabel={{@titleAriaLabel}}
        />
        <ExpandPost @item={{@post}} />
        <div class="time">{{formatDate @post.created_at leaveAgo="true"}}</div>
      </div>

      <div class="excerpt">
        {{#if @post.expandedExcerpt}}
          {{htmlSafe @post.expandedExcerpt}}
        {{else}}
          {{htmlSafe @post.excerpt}}
        {{/if}}
      </div>
    </div>
  </template>
}
