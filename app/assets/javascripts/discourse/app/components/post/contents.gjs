import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { inject as controller } from "@ember/controller";
import { concat } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { TrackedAsyncData } from "ember-async-data";
import { and, lt, not } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DecoratedHtml from "discourse/components/decorated-html";
import ShareTopicModal from "discourse/components/modal/share-topic";
import PluginOutlet from "discourse/components/plugin-outlet";
import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import getURL, { getAbsoluteURL } from "discourse/lib/get-url";
import postActionFeedback from "discourse/lib/post-action-feedback";
import { nativeShare } from "discourse/lib/pwa-utils";
import DiscourseURL from "discourse/lib/url";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import PostEmbedded from "./embedded";
import PostMenu from "./menu";

export default class PostContents extends Component {
  @service appEvents;
  @service capabilities;
  @service site;
  @service siteSettings;

  @controller("topic") topicController;

  @tracked expandedFirstPost = false;
  @tracked repliesBelow = [];
  @tracked
  filteredRepliesShown =
    this.topicController.replies_to_post_number ===
    this.args.post.post_number.toString();

  get filteredRepliesView() {
    return this.siteSettings.enable_filtered_replies_view;
  }

  get groupRequestUrl() {
    return getURL(
      `/g/${this.args.post.requestedGroupName}/requests?filter=${this.args.post.username}`
    );
  }

  get repliesShown() {
    return this.filteredRepliesView
      ? this.filteredRepliesShown
      : this.this.repliesBelow.length > 0;
  }

  @bind
  decoratePostContentBeforeAdopt(element, helper) {
    this.appEvents.trigger(
      "decorate-post-cooked-element:before-adopt",
      element,
      helper
    );
  }

  @bind
  decoratePostContentAfterAdopt(element, helper) {
    this.appEvents.trigger(
      "decorate-post-cooked-element:after-adopt",
      element,
      helper
    );
  }

  @action
  copyLink() {
    // Copying the link to clipboard on mobile doesn't make sense.
    if (this.site.mobileView) {
      return this.share();
    }

    const post = this.args.post;
    const postId = post.id;

    let actionCallback = () => clipboardCopy(getAbsoluteURL(post.shareUrl));

    // Can't use clipboard in JS tests.
    if (isTesting()) {
      actionCallback = () => {};
    }

    postActionFeedback({
      postId,
      actionClass: "post-action-menu__copy-link",
      messageKey: "post.controls.link_copied",
      actionCallback,
      errorCallback: () => this.share(),
    });
  }

  @action
  loadMoreReplies(after = 1) {
    return this.store
      .find("post-reply", { postId: this.args.post.id, after })
      .then((replies) => {
        replies.forEach((reply) => {
          this.repliesBelow.push(reply);
        });
      });
  }

  @action
  async expandFirstPost() {
    this.expandedFirstPost = new TrackedAsyncData(
      await this.args.post.expand()
    );
  }

  @action
  async share() {
    const post = this.args.post;
    try {
      nativeShare(this.capabilities, { url: post.shareUrl });
    } catch {
      const topic = post.topic;
      this.modal.show(ShareTopicModal, {
        model: { category: topic.category, topic, post },
      });
    }
  }

  @action
  async toggleFilteredRepliesView() {
    const post = this.args.post;
    const currentFilterPostNumber =
      this.topic.postStream.filterRepliesToPostNumber;

    if (
      currentFilterPostNumber &&
      currentFilterPostNumber === post.post_number
    ) {
      this.topicController.send("cancelFilter", currentFilterPostNumber);

      this.filteredRepliesShown = false;
      return;
    }

    this.filteredRepliesShown = true;

    await post.get("topic.postStream").filterReplies(post.post_number, post.id);
    this.topicController.updateQueryParams();
  }

  @action
  toggleRepliesBelow(goToPost = false) {
    if (this.repliesBelow.length) {
      this.repliesBelow = [];
      if (goToPost === true) {
        const { topicUrl, post_number } = this.args.post;
        DiscourseURL.routeTo(`${topicUrl}/${post_number}`);
      }
    } else {
      return this.loadMoreReplies();
    }
  }

  <template>
    <PluginOutlet @name="post-content-cooked-html" @post={{@post}}>
      <DecoratedHtml
        @html={{htmlSafe @post.cooked}}
        @decorate={{this.decoratePostContentBeforeAdopt}}
        @decorateAfterAdopt={{this.decoratePostContentAfterAdopt}}
        @className="cooked"
      />
    </PluginOutlet>

    {{#if @post.requestedGroupName}}
      <a href={{this.groupRequestUrl}} class="group-request">
        {{i18n "groups.requests.handle"}}
      </a>
    {{/if}}

    {{#if (and @post.cooked_hidden @post.can_see_hidden_post)}}
      <a class="expand-hidden" {{on "click" this.args.expandHidden}}>
        {{i18n "post.show_hidden"}}
      </a>
    {{/if}}

    {{#if (and (not this.expandedFirstPost.isResolved) @post.expandablePost)}}
      <DButton
        class="expand-post"
        @action={{this.expandFirstPost}}
        @translatedLabel={{if
          this.expandedFirstPost.isPending
          (i18n "loading")
          (concat (i18n "post.show_full") "...")
        }}
      />
    {{/if}}

    <section class="post-menu-area clearfix">
      <PostMenu
        @canCreatePost={{@canCreatePost}}
        @filteredRepliesView={{this.filteredRepliesView}}
        @nextPost={{@nextPost}}
        @post={{@post}}
        @prevPost={{@prevPost}}
        @repliesShown={{@data.repliesShown}}
        @showReadIndicator={{@showReadIndicator}}
        @changeNotice={{@changeNotice}}
        @changePostOwner={{@changePostOwner}}
        @copyLink={{@copyLink}}
        @deletePost={{@deletePost}}
        @editPost={{@editPost}}
        @grantBadge={{@grantBadge}}
        @lockPost={{@lockPost}}
        @permanentlyDeletePost={{@permanentlyDeletePost}}
        @rebakePost={{@rebakePost}}
        @recoverPost={{@recoverPost}}
        @replyToPost={{@replyToPost}}
        @share={{@share}}
        @showFlags={{@showFlags}}
        @showLogin={{@showLogin}}
        @showPagePublish={{@showPagePublish}}
        @toggleLike={{@toggleLike}}
        @togglePostType={{@togglePostType}}
        @toggleReplies={{@toggleReplies}}
        @toggleWiki={{@toggleWiki}}
        @unhidePost={{@unhidePost}}
        @unlockPost={{@unlockPost}}
      />
    </section>

    {{#if this.repliesBelow}}
      <section
        id={{concat "embedded-posts__bottom--" @post.post_number}}
        class="embedded-posts bottom"
      >
        {{#each this.repliesBelow key="id" as |reply|}}
          <PostEmbedded
            role="region"
            aria-label={{i18n
              "post.sr_embedded_reply_description"
              post_number=@post.post_number
              username=reply.username
            }}
            @post={{@reply}}
          />
        {{/each}}

        <DButton
          class="collapse-up"
          @title="post.collapse"
          @icon="chevron-up"
          @action={{this.toggleRepliesBelow}}
          @translatedAriaLabel={{i18n "post.collapse_replies"}}
        />

        {{#if (lt this.repliesBelow @post.replies_count)}}
          <DButton
            class="load-more-replies"
            @label={{i18n "post.show_more_replies"}}
            @action={{this.loadMoreReplies}}
          />
        {{/if}}
      </section>
    {{/if}}
  </template>
}
