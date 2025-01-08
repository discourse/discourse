import Component from "@glimmer/component";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import ExpandPost from "discourse/components/expand-post";
import PostListItemDetails from "discourse/components/post-list/item/details";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import formatDate from "discourse/helpers/format-date";
import { userPath } from "discourse/lib/url";
import dIcon from "discourse-common/helpers/d-icon";

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
      username: this.args.post.draft_username || this.args.post.username,
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
      {{yield to="abovePostItemHeader"}}

      <div class="post-list-item__header info">
        <a
          href={{userPath this.user.username}}
          data-user-card={{this.user.username}}
          class="avatar-link"
        >
          <div class="avatar-wrapper">
            {{avatar
              this.user
              imageSize="large"
              extraClasses="actor"
              ignoreTitle="true"
            }}
          </div>
        </a>

        <PostListItemDetails
          @post={{@post}}
          @titleAriaLabel={{@titleAriaLabel}}
          @user={{this.user}}
        />
        <ExpandPost @item={{@post}} />

        <div class="post-list-item__metadata">
          <span class="time">
            {{formatDate @post.created_at leaveAgo="true"}}
          </span>

          {{#if @post.deleted_by}}
            <span class="delete-info">
              {{dIcon "trash-can"}}
              {{avatar
                @post.deleted_by
                imageSize="tiny"
                extraClasses="actor"
                ignoreTitle="true"
              }}
              {{formatDate @item.deleted_at leaveAgo="true"}}
            </span>
          {{/if}}
        </div>

        {{yield to="belowPostItemMetadata"}}
      </div>

      {{yield to="abovePostItemExcerpt"}}

      <div
        data-topic-id={{@post.topic_id}}
        data-post-id={{@post.id}}
        data-user-id={{@post.user_id}}
        class="excerpt"
      >
        {{#if @post.expandedExcerpt}}
          {{~htmlSafe @post.expandedExcerpt~}}
        {{else}}
          {{~htmlSafe @post.excerpt~}}
        {{/if}}
      </div>

      {{yield to="belowPostItem"}}
    </div>
  </template>
}
