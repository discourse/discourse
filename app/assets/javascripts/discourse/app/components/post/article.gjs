import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as controller } from "@ember/controller";
import { concat, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";
import { and, eq } from "truth-helpers";
import DButton from "discourse/components/d-button";
import TopicMap from "discourse/components/topic-map";
import concatClass from "discourse/helpers/concat-class";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";
import PostAvatar from "./avatar";
import PostBody from "./body";
import PostEmbedded from "./embedded";
import PostNotice from "./notice";

export default class PostArticle extends Component {
  @service site;
  @service siteSettings;
  @service store;

  @controller("topic") topicController;

  @tracked repliesAbove = new TrackedArray();

  get shouldShowTopicMap() {
    if (this.args.post.post_number !== 1) {
      return false;
    }

    const isPM = this.args.post.topic.archetype === "private_message";
    const isRegular = this.args.post.topic.archetype === "regular";
    const showWithoutReplies =
      this.siteSettings.show_topic_map_in_topics_without_replies;

    return (
      this.args.post.topicMap ||
      isPM ||
      (isRegular &&
        (this.args.post.topic.posts_count > 1 || showWithoutReplies))
    );
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

    if (this.repliesAbove.length) {
      // since repliesAbove is a tracked array, let's truncate it instead of creating another one
      this.repliesAbove.length = 0;

      if (goToPost === true) {
        const { post_number } = this.args.post;
        DiscourseURL.routeTo(`${topicUrl}/${post_number}`);
      }
    } else {
      const replies = await this.store.find("post-reply-history", {
        postId: this.args.post.id,
      });

      replies.forEach((reply) => {
        // the components expect a post model instance
        const replyAsPost = this.store.createRecord("post", reply);
        this.repliesAbove.push(replyAsPost);
      });
    }
  }

  <template>
    <article
      ...attributes
      id={{concat "post_" @post.post_number}}
      class={{concatClass
        "boxed"
        "onscreen-post"
        (if this.repliesAbove "replies-above")
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
      {{#if this.repliesAbove}}
        <div class="row">
          <section
            id={{concat "embedded-posts__top--" @post.post_number}}
            class="embedded-posts top topic-body"
          >
            <DButton
              class="collapse-down"
              @icon="chevron-down"
              @title="post.collapse"
            />
            {{#each this.repliesAbove key="id" as |reply|}}
              <PostEmbedded
                @post={{reply}}
                @above={{true}}
                @highlightTerm={{@highlightTerm}}
              />
            {{/each}}
          </section>
        </div>
      {{/if}}
      {{#if (and @post.deleted_at @post.notice)}}
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
          @grantBadge={{@grantBadge}}
          @highlightTerm={{@highlightTerm}}
          @isReplyingDirectlyToPostAbove={{@isReplyingDirectlyToPostAbove}}
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
          @toggleLike={{@toggleLike}}
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
  </template>
}
