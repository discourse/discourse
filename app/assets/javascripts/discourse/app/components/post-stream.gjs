import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, get, hash } from "@ember/helper";
import { action } from "@ember/object";
import { next, schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { and, eq, not } from "truth-helpers";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import PostFilteredNotice from "discourse/components/post/filtered-notice";
import concatClass from "discourse/helpers/concat-class";
import { bind } from "discourse/lib/decorators";
import offsetCalculator from "discourse/lib/offset-calculator";
import { Placeholder } from "discourse/lib/posts-with-placeholders";
import PostStreamViewportTracker from "discourse/modifiers/post-stream-viewport-tracker";
import Post from "./post";
import PostGap from "./post/gap";
import PostPlaceholder from "./post/placeholder";
import PostSmallAction from "./post/small-action";
import PostTimeGap from "./post/time-gap";
import PostVisitedLine from "./post/visited-line";

const DAY_MS = 1000 * 60 * 60 * 24;

export default class PostStream extends Component {
  @service appEvents;
  @service capabilities;
  @service header;
  @service screenTrack;
  @service search;
  @service site;
  @service siteSettings;

  @tracked cloakAbove;
  @tracked cloakBelow;
  @tracked keyboardSelectedPostNumber;

  viewportTracker = new PostStreamViewportTracker();

  constructor() {
    super(...arguments);

    this.#setupEventListeners();
  }

  willDestroy() {
    super.willDestroy(...arguments);

    // clear event listeners
    this.#setupEventListeners(false);
    // clear pending references in the observer
    this.viewportTracker.destroy();
  }

  get gapsBefore() {
    return this.args.gaps?.before || {};
  }

  get gapsAfter() {
    return this.args.gaps?.after || {};
  }

  @cached
  get posts() {
    const postsToRender = this.capabilities.isAndroid
      ? this.args.postStream.posts
      : this.args.postStream.postsWithPlaceholders;

    // TODO (glimmer-post-stream) ideally args.posts should be a TrackedArray
    return postsToRender.toArray();
  }

  get firstAvailablePost() {
    return this.posts[0];
  }

  get highlightTerm() {
    return this.search.highlightTerm;
  }

  get lastAvailablePost() {
    return this.posts.at(-1);
  }

  @cached
  get postTuples() {
    const posts = this.posts;

    const length = posts.length;
    const result = [];

    let i = 0;
    let previousPost = null;

    while (i < length) {
      const post = posts[i];
      const nextPost = i < length - 1 ? posts[i + 1] : null;

      result.push({ post, previousPost, nextPost });

      previousPost = post;
      ++i;
    }

    return result;
  }

  get shouldShowFilteredNotice() {
    return (
      this.args.streamFilters &&
      Object.keys(this.args.streamFilters).length &&
      (Object.keys(this.gapsBefore).length > 0 ||
        Object.keys(this.gapsAfter).length > 0)
    );
  }

  isPlaceholder(post) {
    return post instanceof Placeholder;
  }

  daysBetween(post1, post2) {
    const time1 = post1 ? new Date(post1.created_at).getTime() : null;
    const time2 = post2 ? new Date(post2.created_at).getTime() : null;

    if (!time1 || !time2) {
      return null;
    }

    return Math.floor((time2 - time1) / DAY_MS);
  }

  @bind
  shouldShowTimeGap(daysSince) {
    return daysSince > this.siteSettings.show_time_gap_days;
  }

  @bind
  shouldShowVisitedLine(post, arrayIndex) {
    const postsLength = this.posts.length;
    const maxPostNumber = postsLength > 0 ? this.posts.at(-1).post_number : 0;

    return (
      arrayIndex !== postsLength - 1 && // do not show on the last post displayed
      maxPostNumber <= this.args.highestPostNumber && // do not show in the last existing post
      this.args.lastReadPostNumber === post.post_number
    );
  }

  @action
  loadMoreAbove(post) {
    this.args.topVisibleChanged({
      post,
      refresh: () => {
        const refreshedElem =
          this.viewportTracker.postsOnScreen[post.post_number]?.element;

        if (!refreshedElem) {
          return;
        }

        // The getOffsetTop function calculates the total offset distance of an element from the top of the document.
        // Unlike `element.offsetTop` which only returns the offset relative to its nearest positioned ancestor, this
        // function recursively accumulates the offsetTop of an element and all of its offset parents(ancestors).
        // This ensures the total distance is measured from the very top of the document, accounting for any nested
        // elements and their respective offsets.
        const getOffsetTop = (element) => {
          if (!element) {
            return 0;
          }
          return element.offsetTop + getOffsetTop(element.offsetParent);
        };

        window.scrollTo({
          top: getOffsetTop(refreshedElem) - offsetCalculator(),
        });

        // This seems weird, but somewhat infrequently a rerender
        // will cause the browser to scroll to the top of the document
        // in Chrome. This makes sure the scroll works correctly if that
        // happens.
        schedule("afterRender", () => {
          window.scrollTo({
            top: getOffsetTop(refreshedElem) - offsetCalculator(),
          });
        });
      },
    });
  }

  @action
  loadMoreBelow(post) {
    this.args.bottomVisibleChanged({ post });
  }

  @action
  setCloakingBoundaries(above, below) {
    // requesting an animation frame to update the cloaking boundaries prevents Chrome from logging
    // [Violation] 'setTimeout' handler took <N>ms when scrolling fast
    requestAnimationFrame(() => {
      this.cloakAbove = above;
      this.cloakBelow = below;
    });
  }

  @action
  updateKeyboardSelectedPostNumber({ selectedArticle: element }) {
    next(() => {
      this.keyboardSelectedPostNumber = parseInt(
        element.dataset.postNumber,
        10
      );
    });
  }

  #setupEventListeners(addListeners = true) {
    if (!addListeners) {
      this.appEvents.off(
        "keyboard:move-selection",
        this,
        this.updateKeyboardSelectedPostNumber
      );

      return;
    }

    this.appEvents.on(
      "keyboard:move-selection",
      this,
      this.updateKeyboardSelectedPostNumber
    );
  }

  <template>
    <ConditionalLoadingSpinner @condition={{@postStream.loadingAbove}} />
    <div
      class="post-stream"
      {{this.viewportTracker.setup
        currentPostChanged=@currentPostChanged
        currentPostScrolled=@currentPostScrolled
        headerOffset=this.header.headerOffset
        screenTrack=this.screenTrack
        setCloakingBoundaries=this.setCloakingBoundaries
        topicId=@topic.id
      }}
    >
      {{#if (and (not @postStream.loadingAbove) @postStream.canPrependMore)}}
        <LoadMore @action={{fn this.loadMoreAbove this.firstAvailablePost}} />
      {{/if}}

      {{#each this.postTuples key="post.id" as |tuple index|}}
        {{#let
          tuple.post tuple.previousPost tuple.nextPost
          as |post previousPost nextPost|
        }}
          {{#if (this.isPlaceholder post)}}
            <PostPlaceholder />
          {{else}}
            {{#let (get this.gapsBefore post.id) as |gap|}}
              {{#if gap}}
                <PostGap
                  @post={{post}}
                  @gap={{gap}}
                  @fillGap={{fn @fillGapBefore (hash post=post gap=gap)}}
                />
              {{/if}}
            {{/let}}

            {{#let (this.daysBetween previousPost post) as |daysSince|}}
              {{#if (this.shouldShowTimeGap daysSince)}}
                <PostTimeGap @daysSince={{daysSince}} />
              {{/if}}
            {{/let}}

            {{#let
              (if post.isSmallAction PostSmallAction Post)
              (this.viewportTracker.getCloakingData
                post above=this.cloakAbove below=this.cloakBelow
              )
              as |PostComponent cloakingData|
            }}
              <PostComponent
                id={{concat "post_" post.post_number}}
                class={{concatClass
                  (if cloakingData.active "post-stream--cloaked")
                  (if
                    (eq this.keyboardSelectedPostNumber post.post_number)
                    "selected"
                  )
                }}
                style={{cloakingData.style}}
                @cloaked={{cloakingData.active}}
                @post={{post}}
                @prevPost={{previousPost}}
                @nextPost={{nextPost}}
                @canCreatePost={{@canCreatePost}}
                @cancelFilter={{fn @cancelFilter post}}
                @changeNotice={{fn @changeNotice post}}
                @changePostOwner={{fn @changePostOwner post}}
                @deletePost={{fn @deletePost post}}
                @editPost={{fn @editPost post}}
                @expandHidden={{fn @expandHidden post}}
                @filteringRepliesToPostNumber={{@filteringRepliesToPostNumber}}
                @grantBadge={{fn @grantBadge post}}
                @highlightTerm={{this.highlightTerm}}
                @lockPost={{fn @lockPost post}}
                @multiSelect={{@multiSelect}}
                @permanentlyDeletePost={{fn @permanentlyDeletePost post}}
                @rebakePost={{fn @rebakePost post}}
                @recoverPost={{fn @recoverPost post}}
                @removeAllowedGroup={{fn @removeAllowedGroup post}}
                @removeAllowedUser={{fn @removeAllowedUser post}}
                @replyToPost={{fn @replyToPost post}}
                @selectBelow={{fn @selectBelow post}}
                @selectReplies={{fn @selectReplies post}}
                @selected={{if @multiSelect (@postSelected post)}}
                @showFlags={{fn @showFlags post}}
                @showHistory={{fn @showHistory post}}
                @showInvite={{fn @showInvite post}}
                @showLogin={{fn @showLogin post}}
                @showPagePublish={{fn @showPagePublish post}}
                @showRawEmail={{fn @showRawEmail post}}
                @showReadIndicator={{@showReadIndicator}}
                @togglePostSelection={{fn @togglePostSelection post}}
                @togglePostType={{fn @togglePostType post}}
                @toggleReplyAbove={{fn @toggleReplyAbove post}}
                @toggleWiki={{fn @toggleWiki post}}
                @topicPageQueryParams={{@topicPageQueryParams}}
                @unhidePost={{fn @unhidePost post}}
                @unlockPost={{fn @unlockPost post}}
                @updateTopicPageQueryParams={{@updateTopicPageQueryParams}}
                {{this.viewportTracker.registerPost post}}
              />
            {{/let}}

            {{#let (get this.gapsAfter post.id) as |gap|}}
              {{#if gap}}
                <PostGap
                  @post={{post}}
                  @gap={{gap}}
                  @fillGap={{fn @fillGapAfter (hash post=post gap=gap)}}
                />
              {{/if}}
            {{/let}}

            {{#if (this.shouldShowVisitedLine post index)}}
              <PostVisitedLine @post={{post}} />
            {{/if}}
          {{/if}}
        {{/let}}
      {{/each}}

      {{#unless @postStream.loadingBelow}}
        {{#if @postStream.canAppendMore}}
          <LoadMore @action={{fn this.loadMoreBelow this.lastAvailablePost}} />
        {{else}}
          <div
            class="post-stream__bottom-boundary"
            {{this.viewportTracker.registerBottomBoundary topicId=@topic.id}}
          ></div>
        {{/if}}
      {{/unless}}

      {{#if this.shouldShowFilteredNotice}}
        <PostFilteredNotice
          @posts={{this.posts}}
          @cancelFilter={{@cancelFilter}}
          @streamFilters={{@streamFilters}}
          @filteredPostsCount={{@filteredPostsCount}}
        />
      {{/if}}
    </div>
    <ConditionalLoadingSpinner @condition={{@postStream.loadingBelow}} />
  </template>
}
