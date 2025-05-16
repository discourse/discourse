import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, get, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { TrackedObject, TrackedSet } from "@ember-compat/tracked-built-ins";
import { modifier } from "ember-modifier";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import PostFilteredNotice from "discourse/components/post/filtered-notice";
import { bind } from "discourse/lib/decorators";
import offsetCalculator from "discourse/lib/offset-calculator";
import { Placeholder } from "discourse/lib/posts-with-placeholders";
import DiscourseURL from "discourse/lib/url";
import Post from "./post";
import PostGap from "./post/gap";
import PostPlaceholder from "./post/placeholder";
import PostSmallAction from "./post/small-action";
import PostTimeGap from "./post/time-gap";
import PostVisitedLine from "./post/visited-line";

const MS_PER_DAY = 1000 * 60 * 60 * 24;
const POST_MODEL = Symbol("POST");
const SLACK_FACTOR = 5;

let cloakingEnabled = true;
const cloakingPrevented = new TrackedSet();

export function disableCloaking() {
  cloakingEnabled = false;
}

export function preventCloaking(postId) {
  preventCloaking.add(postId);
}

export default class PostStream extends Component {
  @service appEvents;
  @service capabilities;
  @service header;
  @service screenTrack;
  @service search;
  @service site;
  @service siteSettings;

  @tracked cloakOffset = Math.ceil(window.innerHeight * SLACK_FACTOR);

  observedPostNodes = new Set();
  cloakedPosts = new TrackedObject();
  setCloakedHeight = modifier((element, [cloaking]) => {
    if (cloaking) {
      element.style.height = `${cloaking.height}px`;
      return;
    }

    element.style.height = "";
  });
  viewportObserver;
  cloakingObserver;

  #postsOnScreen = {};

  // #topVisible = null; // Tracks the topmost post currently visible in the viewport
  // #bottomVisible = null; // Tracks the bottommost post currently visible in the viewport
  // #currentPostObj = null; // The current post being viewed/scrolled through
  // #currentVisible = null; // The currently visible post in the viewport (may be different from #currentPostObj)
  // #currentPercent = null;

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

    // disconnect the intersection observers
    this.viewportObserver.disconnect();
    this.cloakingObserver.disconnect();
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
  updateIntersectionObservers(element, _, { headerOffset, cloakOffset }) {
    console.log("updateIntersectionObservers", {
      headerOffset,
      cloakOffset,
    });

    const headerMargin = headerOffset * -1;

    this.cloakingObserver?.disconnect?.();
    this.viewportObserver?.disconnect?.();

    this.cloakingObserver = this.#initializeObserver(this.trackCloakedPosts, {
      rootMargin: `${cloakOffset}px 0px`,
      threshold: 0,
    });

    this.viewportObserver = this.#initializeObserver(this.trackVisiblePosts, {
      rootMargin: `${headerMargin}px 0px 0px 0px`,
      threshold: [0, 1],
    });

    for (const node of this.observedPostNodes) {
      this.cloakingObserver.observe(node);
      this.viewportObserver.observe(node);
    }
  }

  @bind
  registerPostNode(element, [post]) {
    element[POST_MODEL] = post;

    if (!this.observedPostNodes.has(element)) {
      this.observedPostNodes.add(element);
      this.cloakingObserver.observe(element);
      this.viewportObserver.observe(element);
    }
  }

  unregisterPostNode(element) {
    delete element[POST_MODEL];

    this.cloakingObserver.unobserve(element);
    this.viewportObserver.unobserve(element);
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

  @bind
  trackCloakedPosts(event) {
    const { target, isIntersecting } = event;
    const post = target[POST_MODEL];
    // console.log("trackCloakedPosts", {
    //   target,
    //   post,
    //   event,
    // });

    if (isIntersecting) {
      console.log("uncloaked post", {
        post_number: target[POST_MODEL].post_number,
      });
      delete this.cloakedPosts[post.id];
    } else {
      // requestAnimationFrame is used to prevent a `[Violation] Forced reflow while executing JavaScript` warning
      requestAnimationFrame(() => {
        let height = target.clientHeight;

        const style = window.getComputedStyle(target);
        height +=
          parseFloat(style.borderTopWidth) +
          parseFloat(style.borderBottomWidth);

        console.log("cloaked post", {
          post_number: target[POST_MODEL].post_number,
        });
        this.cloakedPosts[post.id] = {
          height,
        };
      });
    }
  }

  @bind
  trackVisiblePosts(event) {
    const { target, isIntersecting } = event;
    const post = target[POST_MODEL];

    if (isIntersecting) {
      this.#postsOnScreen[post.id] = { post, node: target };
      // console.log("entered viewport", {
      //   target,
      //   post,
      //   event,
      // });
    } else {
      delete this.#postsOnScreen[post.id];
      // console.log("exited viewport", {
      //   target,
      //   post,
      //   event,
      // });
    }
  }

  @action
  loadMoreAbove(post) {
    this.args.topVisibleChanged({
      post,
      refresh: () => {
        const refreshedElem = this.#postsOnScreen[post.id]?.node;

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

  #initializeObserver(callback, { rootMargin, threshold }) {
    return new IntersectionObserver(
      (entries) => {
        entries.forEach(callback);
      },
      { threshold, rootMargin, root: document }
    );
  }

  <template>
    <div class="post-stream glimmer-post-stream">
      <ConditionalLoadingSpinner
        @condition={{@postStream.loadingAbove}}
        {{didInsert
          this.updateIntersectionObservers
          headerOffset=this.header.headerOffset
          cloakOffset=this.cloakOffset
        }}
        {{didUpdate
          this.updateIntersectionObservers
          headerOffset=this.header.headerOffset
          cloakOffset=this.cloakOffset
        }}
      >
        {{#if @postStream.canPrependMore}}
          <LoadMore @action={{fn this.loadMoreAbove this.firstAvailablePost}} />
        {{/if}}
      </ConditionalLoadingSpinner>

      {{#each this.postTuples key="post.id" as |tuple index|}}
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

            {{#let
              (if post.isSmallAction PostSmallAction Post)
              (get this.cloakedPosts post.id)
              as |PostComponent cloaked|
            }}
              <PostComponent
                @cloaked={{cloaked}}
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
                {{this.setCloakedHeight cloaked}}
                {{didInsert this.registerPostNode post}}
                {{didUpdate this.registerPostNode post cloaked}}
                {{willDestroy this.unregisterPostNode post}}
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
