import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DecoratedHtml from "discourse/components/decorated-html";
import ExpandPost from "discourse/components/expand-post";
import PostListItemDetails from "discourse/components/post-list/item/details";
import avatar from "discourse/helpers/avatar";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import { bind } from "discourse/lib/decorators";
import { userPath } from "discourse/lib/url";

export default class PostListItem extends Component {
  @service site;
  @service siteSettings;
  @service currentUser;
  @service appEvents;

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
    return this.args.post.hidden && !this.currentUser?.staff;
  }

  get deletedClass() {
    return this.args.post.deleted ? "deleted" : "";
  }

  get user() {
    return {
      id: this.args.post.user_id,
      name: this.args.post.name,
      username: this.args.usernamePath
        ? this.args.post[this.args.usernamePath]
        : this.args.post.username,
      avatar_template: this.args.post.avatar_template,
      title: this.args.post.user_title,
      primary_group_name: this.args.post.primary_group_name,
    };
  }

  get postId() {
    return this.args.idPath
      ? this.args.post[this.args.idPath]
      : this.args.post.id;
  }

  get isDraft() {
    return this.args.post.constructor.name === "UserDraft";
  }

  get draftIcon() {
    const key = this.args.post.draft_key;

    if (key.startsWith("new_private_message")) {
      return "envelope";
    } else if (key.startsWith("new_topic")) {
      return "layer-group";
    } else {
      return "reply";
    }
  }

  @bind
  decoratePostContent(element, helper) {
    this.appEvents.trigger(
      "decorate-non-stream-cooked-element",
      element,
      helper
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
    >
      {{yield to="abovePostItemHeader"}}

      <div class="post-list-item__header info">
        {{#if this.isDraft}}
          <div class="draft-icon">
            {{icon this.draftIcon class="icon"}}
          </div>
        {{else}}
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
        {{/if}}

        <PostListItemDetails
          @post={{@post}}
          @titleAriaLabel={{@titleAriaLabel}}
          @titlePath={{@titlePath}}
          @urlPath={{@urlPath}}
          @user={{this.user}}
          @showUserInfo={{@showUserInfo}}
          @isDraft={{this.isDraft}}
          @resumeDraft={{@resumeDraft}}
        />

        {{#unless @post.draftType}}
          <ExpandPost @item={{@post}} />
        {{/unless}}

        {{#if @post.editableDraft}}
          <div class="user-stream-item-draft-actions">
            <DButton
              @action={{fn @resumeDraft @post}}
              @icon="pencil"
              @title="drafts.resume"
              class="btn-default resume-draft"
            />
            <DButton
              @action={{fn @removeDraft @post}}
              @icon="trash-can"
              @title="drafts.remove"
              class="btn-danger remove-draft"
            />
          </div>
        {{/if}}

        {{yield to="belowPostItemMetadata"}}
      </div>

      {{yield to="abovePostItemExcerpt"}}

      <div
        data-topic-id={{@post.topic_id}}
        data-post-id={{this.postId}}
        data-user-id={{@post.user_id}}
        class="excerpt"
      >
        <DecoratedHtml
          @html={{htmlSafe (or @post.expandedExcerpt @post.excerpt)}}
          @decorate={{this.decoratePostContent}}
          @className="cooked"
        />
      </div>

      {{yield to="belowPostItem"}}
    </div>
  </template>
}
