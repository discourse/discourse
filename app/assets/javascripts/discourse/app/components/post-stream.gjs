import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { fn, get, hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import PostFilteredNotice from "discourse/components/post/filtered-notice";
import { bind } from "discourse/lib/decorators";
import { Placeholder } from "discourse/lib/posts-with-placeholders";
import DiscourseURL from "discourse/lib/url";
import Post from "./post";
import PostGap from "./post/gap";
import PostPlaceholder from "./post/placeholder";
import PostSmallAction from "./post/small-action";
import PostTimeGap from "./post/time-gap";
import PostVisitedLine from "./post/visited-line";

const MS_PER_DAY = 1000 * 60 * 60 * 24;

export default class PostStream extends Component {
  @service appEvents;
  @service capabilities;
  @service screenTrack;
  @service search;
  @service site;
  @service siteSettings;

  constructor() {
    super(...arguments);

    this._previouslyNearby = new Set();

    const opts = {
      passive: true,
    };
    document.addEventListener("touchmove", this._debouncedScroll, opts);
    window.addEventListener("scroll", this._debouncedScroll, opts);

    // TODO (glimmer-post-stream) do we need this?
    // if (this.site.useGlimmerPostStream) {
    //   next(() => this._scrollTriggered());
    // } else {
    //   this._scrollTriggered();
    // }

    // TODO (glimmer-post-stream) do we need this?
    this.appEvents.on("post-stream:refresh", this, "_debouncedScroll");
    this.appEvents.on("post-stream:posted", this, "_posted");

    // restore scroll position on browsers with aggressive BFCaches (like Safari)
    window.onpageshow = function (event) {
      if (event.persisted) {
        DiscourseURL.routeTo(this.location.pathname);
      }
    };
  }

  willDestroy() {
    super.willDestroy(...arguments);

    document.removeEventListener("touchmove", this._debouncedScroll);
    window.removeEventListener("scroll", this._debouncedScroll);

    this.appEvents.off("post-stream:refresh", this, "_debouncedScroll");
    this.appEvents.off("post-stream:refresh", this, "_refresh");
    this.appEvents.off("post-stream:posted", this, "_posted");
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

  get highlightTerm() {
    return this.search.highlightTerm;
  }

  isPlaceholder(post) {
    return post instanceof Placeholder;
  }

  daysBetween(post1, post2) {
    const time1 = post1 ? new Date(post1.createdAt).getTime() : null;
    const time2 = post2 ? new Date(post2.createdAt).getTime() : null;

    if (!time1 || !time2) {
      return null;
    }

    return Math.floor((time2 - time1) / MS_PER_DAY);
  }

  get shouldShowFilteredNotice() {
    return (
      this.args.streamFilters &&
      Object.keys(this.args.streamFilters).length &&
      (Object.keys(this.gapsBefore).length > 0 ||
        Object.keys(this.gapsAfter).length > 0)
    );
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
  loadMoreAbove(firstAvailablePost) {
    this.args.topVisibleChanged({ post: firstAvailablePost });
  }

  @action
  loadMoreBelow(lastAvailablePost) {
    this.args.bottomVisibleChanged({ post: lastAvailablePost });
  }

  <template>
    <div class="post-stream glimmer-post-stream">
      <ConditionalLoadingSpinner @condition={{@postStream.loadingAbove}}>
        {{#if @postStream.canPrependMore}}
          <LoadMore @action={{fn this.loadMoreAbove this.firstAvailablePost}} />
        {{/if}}
      </ConditionalLoadingSpinner>

      {{#each this.postTuples as |tuple index|}}
        {{#let
          (get tuple "post") (get tuple "previousPost") (get tuple "nextPost")
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

            {{#if post.isSmallAction}}
              <PostSmallAction
                @post={{post}}
                @deletePost={{fn @deletePost post}}
                @editPost={{fn @editPost post}}
                @recoverPost={{fn @recoverPost post}}
              />
            {{else}}
              <Post
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
                @selected={{@selected}}
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
              />
            {{/if}}

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

      <ConditionalLoadingSpinner @condition={{@postStream.loadingBelow}}>
        {{#if @postStream.canAppendMore}}
          <LoadMore @action={{fn this.loadMoreBelow this.lastAvailablePost}} />
        {{/if}}
      </ConditionalLoadingSpinner>

      {{#if this.shouldShowFilteredNotice}}
        <PostFilteredNotice
          @posts={{this.posts}}
          @cancelFilter={{@cancelFilter}}
          @streamFilters={{@streamFilters}}
          @filteredPostsCount={{@filteredPostsCount}}
        />
      {{/if}}
    </div>
  </template>
}
