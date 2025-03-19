import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as controller } from "@ember/controller";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedAsyncData } from "ember-async-data";
import { and, eq, not, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import PostAvatar from "discourse/components/post/avatar";
import PostBody from "discourse/components/post/body";
import PostEmbedded from "discourse/components/post/embedded";
import PostNotice from "discourse/components/post/notice";
import TopicMap from "discourse/components/topic-map";
import concatClass from "discourse/helpers/concat-class";
import { applyValueTransformer } from "discourse/lib/transformer";
import DiscourseURL from "discourse/lib/url";
import parentClass from "discourse/modifiers/parent-class";
import { i18n } from "discourse-i18n";

export default class Post extends Component {
  @service appEvents;
  @service currentUser;
  @service dialog;
  @service keyValueStore;
  @service search;
  @service site;
  @service siteSettings;
  @service store;

  @controller("topic") topicController;

  @tracked repliesAbove;

  get additionalClasses() {
    return applyValueTransformer("post-class", [], {
      post: this.args.post,
    });
  }

  get hasRepliesAbove() {
    return this.repliesAbove?.isResolved && this.repliesAbove.value.length > 0;
  }

  get id() {
    return `post_${this.args.post.post_number}`;
  }

  get isReplyingDirectlyToPostAbove() {
    return (
      this.args.prevPost &&
      this.args.post.reply_to_post_number === this.args.prevPost.post_number &&
      this.args.post.id !==
        this.args.post.topic?.postStream?.filterUpwardsPostID
    );
  }

  get shouldShowTopicMap() {
    if (this.args.post.post_number !== 1) {
      return false;
    }

    const isPM = this.args.post.topic.archetype === "private_message";
    const isRegular = this.args.post.topic.archetype === "regular";
    const showWithoutReplies =
      this.siteSettings.show_topic_map_in_topics_without_replies;

    return applyValueTransformer(
      "post-show-topic-map",
      isPM ||
        (isRegular &&
          (this.args.post.topic.posts_count > 1 || showWithoutReplies)),
      { post: this.args.post, isPM, isRegular, showWithoutReplies }
    );
  }

  get staged() {
    return (
      this.args.post.id === -1 ||
      this.args.post.isSaving ||
      this.args.post.staged
    );
  }

  @action
  async toggleLike() {
    const post = this.args.post;
    const likeAction = post.likeAction;

    if (likeAction?.canToggle) {
      const result = await likeAction.togglePromise(post);

      this.appEvents.trigger("page:like-toggled", post, likeAction);
      return this.#warnIfClose(result);
    }
  }

  @action
  async toggleReplyAbove(goToPost = false) {
    const replyPostNumber = this.args.post.reply_to_post_number;

    if (this.siteSettings.enable_filtered_replies_view) {
      await this.args.post.topic?.postStream?.filterUpwards?.(
        this.args.post.id
      );
      this.topicController.updateQueryParams();
    }

    const topicUrl = this.args.post.topicUrl;

    // jump directly on mobile
    if (this.site.mobileView) {
      if (topicUrl) {
        DiscourseURL.routeTo(`${topicUrl}/${replyPostNumber}`);
      }

      return;
    }

    if (this.repliesAbove?.value.length) {
      this.repliesAbove = null;

      if (goToPost === true) {
        const { post_number } = this.args.post;
        DiscourseURL.routeTo(`${topicUrl}/${post_number}`);
      }
    } else {
      this.repliesAbove = new TrackedAsyncData(this.#loadRepliesAbove());
    }
  }

  #warnIfClose(result) {
    if (!result || !result.acted) {
      return;
    }

    const lastWarnedLikes = this.keyValueStore.get("lastWarnedLikes");

    // only warn once per day
    const yesterday = Date.now() - 1000 * 60 * 60 * 24;
    if (lastWarnedLikes && parseInt(lastWarnedLikes, 10) > yesterday) {
      return;
    }

    const { remaining, max } = result;
    const threshold = Math.ceil(max * 0.1);

    if (remaining === threshold) {
      this.dialog.alert(i18n("post.few_likes_left"));
      this.keyValueStore.set({ key: "lastWarnedLikes", value: Date.now() });
    }
  }

  async #loadRepliesAbove() {
    const replies = await this.store.find("post-reply-history", {
      postId: this.args.post.id,
    });

    return replies.map((reply) => this.store.createRecord("post", reply));
  }

  <template>
    {{#unless @cloaked}}
      <article
        {{parentClass
          (concatClass
            "topic-post"
            "clearfix"
            (if this.staged "staged")
            (if @selected "selected")
            (if @post.topicOwner "topic-owner")
            (if (eq this.currentUser.id @post.user_id) "current-user-post")
            (if @post.group_moderator "category-moderator")
            (if @post.hidden "post-hidden")
            (if @post.deleted "deleted")
            (if
              @post.primary_group_name
              (concat "group-" @post.primary_group_name)
            )
            (if @post.wiki "wiki")
            (if @post.isWhisper "whisper")
            (if
              (or @post.isModeratorAction (and @post.isWarning @post.firstPost))
              "moderator"
              "regular"
            )
            (if @post.user_suspended "user-suspended")
            this.additionalClasses
          )
          parentSelector=".topic-post.glimmer-post-stream"
        }}
        ...attributes
        id={{this.id}}
        class={{concatClass
          "boxed"
          "onscreen-post"
          (if this.hasRepliesAbove "replies-above")
          (if @post.is_auto_generated "is-auto-generated")
          (if @post.via_email "via-email")
        }}
        aria-label={{i18n
          "share.post"
          (hash postNumber=@post.post_number username=@post.username)
        }}
        role="region"
        data-post-id={{@post.id}}
        data-topic-id={{@post.topicId}}
        data-user-id={{@post.user_id}}
      >
        {{#if this.hasRepliesAbove}}
          <div class="row">
            <section
              id={{concat "embedded-posts__top--" @post.post_number}}
              class="embedded-posts top topic-body"
            >
              <DButton
                class="collapse-down"
                @action={{this.toggleReplyAbove}}
                @icon="chevron-down"
                @title="post.collapse"
              />
              {{#each this.repliesAbove.value key="id" as |reply|}}
                <PostEmbedded
                  @post={{reply}}
                  @above={{true}}
                  @highlightTerm={{@highlightTerm}}
                />
              {{/each}}
            </section>
          </div>
        {{/if}}
        {{#if (and (not @post.deletedAt) @post.notice)}}
          <div class="row">
            <PostNotice @post={{@post}} />
          </div>
        {{/if}}
        <div class="row">
          <PostAvatar @post={{@post}} />
          <PostBody
            @post={{@post}}
            @prevPost={{@prevPost}}
            @nextPost={{@nextPost}}
            @canCreatePost={{@canCreatePost}}
            @changeNotice={{@changeNotice}}
            @changePostOwner={{@changePostOwner}}
            @deletePost={{@deletePost}}
            @editPost={{@editPost}}
            @expandHidden={{@expandHidden}}
            @grantBadge={{@grantBadge}}
            @hasRepliesAbove={{this.hasRepliesAbove}}
            @highlightTerm={{this.search.highlightTerm}}
            @isReplyingDirectlyToPostAbove={{this.isReplyingDirectlyToPostAbove}}
            @lockPost={{@lockPost}}
            @multiSelect={{@multiSelect}}
            @permanentlyDeletePost={{@permanentlyDeletePost}}
            @rebakePost={{@rebakePost}}
            @recoverPost={{@recoverPost}}
            @repliesAbove={{this.repliesAbove}}
            @replyToPost={{@replyToPost}}
            @selectBelow={{@selectBelow}}
            @selectReplies={{@selectReplies}}
            @selected={{@selected}}
            @showFlags={{@showFlags}}
            @showHistory={{@showHistory}}
            @showLogin={{@showLogin}}
            @showPagePublish={{@showPagePublish}}
            @showRawEmail={{@showRawEmail}}
            @showReadIndicator={{@showReadIndicator}}
            @toggleLike={{this.toggleLike}}
            @togglePostSelection={{@togglePostSelection}}
            @togglePostType={{@togglePostType}}
            @toggleReplyAbove={{this.toggleReplyAbove}}
            @toggleWiki={{@toggleWiki}}
            @unhidePost={{@unhidePost}}
            @unlockPost={{@unlockPost}}
          />
        </div>
        {{#if this.shouldShowTopicMap}}
          <div class="topic-map --op">
            <TopicMap
              @model={{@post.topic}}
              @cancelFilter={{@cancelFilter}}
              @topicDetails={{@post.topic.details}}
              @postStream={{@post.topic.postStream}}
              @showPMMap={{eq @post.topic.archetype "private_message"}}
              @showInvite={{@showInvite}}
              @removeAllowedGroup={{@removeAllowedGroup}}
              @removeAllowedUser={{@removeAllowedUser}}
            />
          </div>
        {{/if}}
      </article>
    {{/unless}}
  </template>
}
