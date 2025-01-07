import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import DButton from "discourse/components/d-button";
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

  get user() {
    return {
      id: this.args.post.user_id,
      name: this.args.post.name,
      username: this.args.post.username,
      avatar_template: this.args.post.avatar_template,
      title: this.args.post.user_title,
      primary_group_name: this.args.post.primary_group_name,
    };
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
          href={{userPath this.user.username}}
          data-user-card={{this.user.username}}
          class="avatar-link"
        >
          {{avatar
            this.user
            imageSize="large"
            extraClasses="actor"
            ignoreTitle="true"
          }}
        </a>

        <PostListItemDetails
          @post={{@post}}
          @titleAriaLabel={{@titleAriaLabel}}
          @user={{this.user}}
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

      {{yield to="belowPostItem"}}
    </div>
  </template>
}
