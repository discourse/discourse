import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { resolveAllShortUrls } from "pretty-text/upload-short-url";
import ExpandPost from "discourse/components/expand-post";
import PostListItemDetails from "discourse/components/post-list/item/details";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import formatDate from "discourse/helpers/format-date";
import { ajax } from "discourse/lib/ajax";
import { loadOneboxes } from "discourse/lib/load-oneboxes";
import { userPath } from "discourse/lib/url";
import dIcon from "discourse/helpers/d-icon";

export default class PostListItem extends Component {
  @service site;
  @service siteSettings;
  @service currentUser;

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

  get hiddenClass() {
    return (
      this.args.post.hidden && !(this.currentUser && this.currentUser.staff)
    );
  }

  get deletedClass() {
    return this.args.post.deleted ? "deleted" : "";
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

  @action
  buildOneboxes(element) {
    schedule("afterRender", () => {
      loadOneboxes(
        element,
        ajax,
        this.args.post.topic_id,
        this.args.post.category_id,
        this.siteSettings.max_oneboxes_per_post,
        true
      );
    });
  }

  @action
  resolveShortUrls(element) {
    resolveAllShortUrls(
      ajax,
      this.siteSettings,
      element,
      this.args.shortUrlOpts
    );
  }

  <template>
    <div
      class="post-list-item
        {{concatClass
          this.moderatorActionClass
          this.primaryGroupClass
          this.hiddenClass
          @additionalItemClasses
        }}"
      {{didInsert this.buildOneboxes @post}}
      {{didInsert this.resolveShortUrls @post}}
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
          @showUserInfo={{@showUserInfo}}
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
