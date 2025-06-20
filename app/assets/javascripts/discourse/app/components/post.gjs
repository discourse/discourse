import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { TrackedArray, TrackedMap } from "@ember-compat/tracked-built-ins";
import { TrackedAsyncData } from "ember-async-data";
import { and, eq, not, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import ShareTopicModal from "discourse/components/modal/share-topic";
import PluginOutlet from "discourse/components/plugin-outlet";
import PostActionsSummary from "discourse/components/post/actions-summary";
import PostAvatar from "discourse/components/post/avatar";
import PostCookedHtml from "discourse/components/post/cooked-html";
import PostEmbedded from "discourse/components/post/embedded";
import PostLinks from "discourse/components/post/links";
import PostMenu from "discourse/components/post/menu";
import PostMetaData from "discourse/components/post/meta-data";
import PostMetaDataReplyToTab from "discourse/components/post/meta-data/reply-to-tab";
import PostNotice from "discourse/components/post/notice";
import TopicMap from "discourse/components/topic-map";
import concatClass from "discourse/helpers/concat-class";
import lazyHash from "discourse/helpers/lazy-hash";
import { isTesting } from "discourse/lib/environment";
import getURL, { getAbsoluteURL } from "discourse/lib/get-url";
import postActionFeedback from "discourse/lib/post-action-feedback";
import { nativeShare } from "discourse/lib/pwa-utils";
import { applyValueTransformer } from "discourse/lib/transformer";
import DiscourseURL from "discourse/lib/url";
import { clipboardCopy } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class Post extends Component {
  @service appEvents;
  @service capabilities;
  @service currentUser;
  @service dialog;
  @service keyValueStore;
  @service modal;
  @service search;
  @service site;
  @service siteSettings;
  @service store;

  @tracked expandedFirstPost;
  @tracked repliesAbove;
  @tracked repliesBelow = new TrackedArray();

  decoratorState = new TrackedMap();

  get additionalClasses() {
    return applyValueTransformer("post-class", [], {
      post: this.args.post,
    });
  }

  get canLoadMoreRepliesBelow() {
    return this.repliesBelow.length < this.args.post.reply_count;
  }

  get filteredRepliesShown() {
    return (
      this.args.filteringRepliesToPostNumber ===
      this.args.post.post_number.toString()
    );
  }

  get filteredRepliesView() {
    return this.siteSettings.enable_filtered_replies_view;
  }

  get groupRequestUrl() {
    return getURL(
      `/g/${this.args.post.requestedGroupName}/requests?filter=${this.args.post.username}`
    );
  }

  get hasRepliesAbove() {
    return this.repliesAbove?.isResolved && this.repliesAbove.value.length > 0;
  }

  get id() {
    return `post_${this.args.post.post_number}`;
  }

  get isFromCurrentUser() {
    return this.currentUser && this.currentUser.id === this.args.post.user_id;
  }

  get isReplyingDirectlyToPostAbove() {
    return (
      this.args.prevPost &&
      this.args.post.reply_to_post_number === this.args.prevPost.post_number &&
      this.args.post.id !==
        this.args.post.topic?.postStream?.filterUpwardsPostID
    );
  }

  get isReplyToTabDisplayed() {
    return PostMetaDataReplyToTab.shouldRender(
      {
        post: this.args.post,
        isReplyingDirectlyToPostAbove: this.isReplyingDirectlyToPostAbove,
      },
      null,
      getOwner(this)
    );
  }

  get minHeight() {
    return this.args.height ? `${this.args.height}px` : null;
  }

  get repliesShown() {
    return this.filteredRepliesView
      ? this.filteredRepliesShown
      : this.repliesBelow.length > 0;
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
  async loadMoreReplies() {
    const after = this.repliesBelow.length
      ? this.repliesBelow.at(-1).post_number
      : 1;

    const replies = await this.store.find("post-reply", {
      postId: this.args.post.id,
      after,
    });

    replies.forEach((reply) => {
      // the components expect a post model instance
      const replyAsPost = this.store.createRecord("post", reply);
      this.repliesBelow.push(replyAsPost);
    });
  }

  @action
  async expandFirstPost() {
    this.expandedFirstPost = new TrackedAsyncData(this.args.post.expand());
  }

  @action
  async share() {
    const post = this.args.post;

    try {
      await nativeShare(this.capabilities, { url: post.shareUrl });
    } catch {
      // if a native share dialog is not available, fallback to our share modal
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
      this.args.post.topic.postStream.filterRepliesToPostNumber;

    if (
      currentFilterPostNumber &&
      currentFilterPostNumber === post.post_number
    ) {
      this.args.cancelFilter(currentFilterPostNumber);
      return;
    }

    await post.get("topic.postStream").filterReplies(post.post_number, post.id);
    this.args.updateTopicPageQueryParams();
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
      this.args.updateTopicPageQueryParams();
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

  @action
  async toggleReplies() {
    return this.filteredRepliesView
      ? await this.toggleFilteredRepliesView()
      : await this.toggleRepliesBelow();
  }

  @action
  toggleRepliesBelow(goToPost = false) {
    if (this.repliesBelow.length) {
      // since repliesBelow is a tracked array, let's truncate it instead of creating another one
      this.repliesBelow.length = 0;

      if (goToPost === true) {
        const { topicUrl, post_number } = this.args.post;
        DiscourseURL.routeTo(`${topicUrl}/${post_number}`);
      }
    } else {
      return this.loadMoreReplies();
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
    <div
      ...attributes
      class={{unless
        @cloaked
        (concatClass
          "topic-post"
          "clearfix"
          (unless this.site.mobileView "post--sticky-avatar sticky-avatar")
          (if this.staged "post--staged staged")
          (if @selected "post--selected selected")
          (if @post.topicOwner "post--topic-owner topic-owner")
          (if this.isFromCurrentUser "post--current-user current-user-post")
          (if
            @post.group_moderator "post--category-moderator category-moderator"
          )
          (if @post.hidden "post--hidden post-hidden")
          (if @post.deleted "post--deleted deleted")
          (if
            @post.primary_group_name
            (concatClass
              (concat "post--group-" @post.primary_group_name)
              (concat "group-" @post.primary_group_name)
            )
          )
          (if @post.wiki "post--wiki wiki")
          (if @post.isWhisper "post--whisper whisper")
          (if
            (or @post.isModeratorAction (and @post.isWarning @post.firstPost))
            "post--moderator moderator"
            "post--regular regular"
          )
          (if @post.user_suspended "post--user-suspended user-suspended")
          this.additionalClasses
        )
      }}
      data-post-number={{@post.post_number}}
      {{! The post component is wrapped in a `div` and sets the same `id` below in the `article` tag,
          we need to only set it in the `div` when the post is cloaked.
          This is not ideal, but the post-stream component sets the `id` for the children to ensure
          all cloaked items can be referenced and we need to override it }}
      id={{if @cloaked (concat "post_" @post.post_number)}}
    >
      {{#unless @cloaked}}
        {{#let
          (lazyHash
            post=@post
            actions=(hash
              updateTopicPageQueryParams=@updateTopicPageQueryParams
            )
            decoratorState=this.decoratorState
            topicPageQueryParams=@topicPageQueryParams
          )
          as |postOutletArgs|
        }}
          <PluginOutlet @name="post-article" @outletArgs={{postOutletArgs}}>
            <article
              id={{this.id}}
              class={{concatClass
                "boxed"
                "onscreen-post"
                (if
                  this.hasRepliesAbove "post--has-replies-above replies-above"
                )
                (if
                  @post.is_auto_generated
                  "post--auto-generated is-auto-generated"
                )
                (if @post.via_email "post--via-email via-email")
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
                <div class="post__row row">
                  <section
                    id={{concat "embedded-posts__top--" @post.post_number}}
                    class="post__embedded-posts post__embedded-posts--top post__body embedded-posts top topic-body"
                  >
                    <DButton
                      class="post__collapse-button post__collapse-button-down collapse-down"
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
                <div class="post__row row">
                  <PostNotice @post={{@post}} />
                </div>
              {{/if}}
              <div class="post__row row">
                <PostAvatar @post={{@post}} />
                <div class="post__body topic-body clearfix">
                  <PluginOutlet
                    @name="post-metadata"
                    @outletArgs={{postOutletArgs}}
                  >
                    <PostMetaData
                      @post={{@post}}
                      @editPost={{@editPost}}
                      @hasRepliesAbove={{this.hasRepliesAbove}}
                      @isReplyingDirectlyToPostAbove={{this.isReplyingDirectlyToPostAbove}}
                      @multiSelect={{@multiSelect}}
                      @repliesAbove={{this.repliesAbove}}
                      @selectBelow={{@selectBelow}}
                      @selectReplies={{@selectReplies}}
                      @selected={{@selected}}
                      @showHistory={{@showHistory}}
                      @showRawEmail={{@showRawEmail}}
                      @togglePostSelection={{@togglePostSelection}}
                      @toggleReplyAbove={{this.toggleReplyAbove}}
                    />
                  </PluginOutlet>
                  <div
                    class={{concatClass
                      "post__regular regular"
                      (unless this.repliesShown "post__contents contents")
                      (if
                        this.isReplyToTabDisplayed
                        "post__contents--avoid-tab avoid-tab"
                      )
                    }}
                  >
                    <PluginOutlet
                      @name="post-content-cooked-html"
                      @outletArgs={{postOutletArgs}}
                    >
                      <PostCookedHtml
                        @post={{@post}}
                        @highlightTerm={{@highlightTerm}}
                        @decoratorState={{this.decoratorState}}
                      />
                    </PluginOutlet>

                    {{#if @post.requestedGroupName}}
                      <div class="post__group-request group-request">
                        <a href={{this.groupRequestUrl}}>
                          {{i18n "groups.requests.handle"}}
                        </a>
                      </div>
                    {{/if}}

                    {{#if (and @post.cooked_hidden @post.can_see_hidden_post)}}
                      {{! template-lint-disable no-invalid-interactive }}
                      <a
                        class="post__expand-hidden expand-hidden"
                        {{on "click" @expandHidden}}
                      >
                        {{i18n "post.show_hidden"}}
                      </a>
                    {{/if}}

                    {{#if
                      (and
                        (not this.expandedFirstPost.isResolved)
                        @post.expandablePost
                      )
                    }}
                      <DButton
                        class="post__expand-button expand-post"
                        @action={{this.expandFirstPost}}
                        @translatedLabel={{if
                          this.expandedFirstPost.isPending
                          (i18n "loading")
                          (concat (i18n "post.show_full") "...")
                        }}
                      />
                    {{/if}}

                    <section class="post__menu-area post-menu-area clearfix">
                      <PostMenu
                        @post={{@post}}
                        @prevPost={{@prevPost}}
                        @nextPost={{@nextPost}}
                        @canCreatePost={{@canCreatePost}}
                        @changeNotice={{@changeNotice}}
                        @changePostOwner={{@changePostOwner}}
                        @copyLink={{this.copyLink}}
                        @deletePost={{@deletePost}}
                        @editPost={{@editPost}}
                        @filteredRepliesView={{this.filteredRepliesView}}
                        @grantBadge={{@grantBadge}}
                        @lockPost={{@lockPost}}
                        @permanentlyDeletePost={{@permanentlyDeletePost}}
                        @rebakePost={{@rebakePost}}
                        @recoverPost={{@recoverPost}}
                        @repliesShown={{this.repliesShown}}
                        @replyToPost={{@replyToPost}}
                        @share={{this.share}}
                        @showFlags={{@showFlags}}
                        @showLogin={{@showLogin}}
                        @showPagePublish={{@showPagePublish}}
                        @showReadIndicator={{@showReadIndicator}}
                        @toggleLike={{this.toggleLike}}
                        @togglePostType={{@togglePostType}}
                        @toggleReplies={{this.toggleReplies}}
                        @toggleWiki={{@toggleWiki}}
                        @unhidePost={{@unhidePost}}
                        @unlockPost={{@unlockPost}}
                      />
                    </section>

                    {{#if this.repliesBelow}}
                      <section
                        id={{concat
                          "embedded-posts__bottom--"
                          @post.post_number
                        }}
                        class="post__embedded-posts post__embedded-posts--bottom embedded-posts bottom"
                      >
                        {{#each this.repliesBelow key="id" as |reply|}}
                          <PostEmbedded
                            role="region"
                            aria-label={{i18n
                              "post.sr_embedded_reply_description"
                              post_number=@post.post_number
                              username=reply.username
                            }}
                            @post={{reply}}
                            @highlightTerm={{@highlightTerm}}
                          />
                        {{/each}}

                        <DButton
                          class="post__collapse-button post__collapse-button-up collapse-up"
                          @action={{this.toggleRepliesBelow}}
                          @ariaLabel="post.sr_collapse_replies"
                          @icon="chevron-up"
                          @title="post.collapse"
                        />

                        {{#if this.canLoadMoreRepliesBelow}}
                          <DButton
                            class="post__load-more load-more-replies"
                            @label="post.load_more_replies"
                            @action={{this.loadMoreReplies}}
                          />
                        {{/if}}
                      </section>
                    {{/if}}
                  </div>

                  <section class="post__actions post-actions">
                    <PostActionsSummary @post={{@post}} />
                  </section>
                  <PostLinks @post={{@post}} />
                </div>
              </div>
              {{#if this.shouldShowTopicMap}}
                <div class="post__topic-map topic-map --op">
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
          </PluginOutlet>
        {{/let}}
      {{/unless}}
    </div>
  </template>
}
