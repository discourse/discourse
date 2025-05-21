import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn, get, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { TrackedSet } from "@ember-compat/tracked-built-ins";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import LoadMore from "discourse/components/load-more";
import PostFilteredNotice from "discourse/components/post/filtered-notice";
import discourseDebounce from "discourse/lib/debounce";
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

const CLOAKABLE_CLASS = "post-stream__cloakable-item";
const CLOAKABLE_CLASS_SELECTOR = `.${CLOAKABLE_CLASS}`;
const DAY_MS = 1000 * 60 * 60 * 24;
const POST_MODEL = Symbol("POST");
const RESIZE_DEBOUNCE_MS = 100;
const SCROLL_BATCH_INTERVAL_MS = 10;
const SLACK_FACTOR = 5;

let cloakingEnabled = true;
const cloakingPrevented = new TrackedSet();

export function disableCloaking() {
  cloakingEnabled = false;
}

export function preventCloaking(postId) {
  cloakingPrevented.add(postId);
}

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
  @tracked cloakOffset;

  observedPostNodes = new Set();
  uncloakedPostNumbers = new Set();

  #cloakedPostsHeight = {};
  #cloakingObserver;
  #currentPostElement;
  #currentPostObserver;
  #postsOnScreen = {};
  #observedCloakBoundaries = {
    above: null,
    below: null,
  };
  #onScreenBoundaries = {
    min: null,
    max: null,
  };
  #viewportObserver;

  // #topVisible = null; // Tracks the topmost post currently visible in the viewport
  // #bottomVisible = null; // Tracks the bottommost post currently visible in the viewport
  // #currentPostObj = null; // The current post being viewed/scrolled through
  // #currentVisible = null; // The currently visible post in the viewport (may be different from #currentPostObj)
  // #currentPercent = null;

  constructor() {
    super(...arguments);

    // initialize the cloaking offset area
    this.#updateCloakOffset();

    // TODO (glimmer-post-stream) do we need this?
    // this.appEvents.on("post-stream:refresh", this, "_debouncedScroll");
    this.appEvents.on("post-stream:posted", this, "_posted");

    // track the window height to update the cloaking area
    window.addEventListener("resize", this.#onWindowResize, {
      passive: true,
    });

    // restore scroll position on browsers with aggressive BFCaches (like Safari)
    window.onpageshow = function (event) {
      if (event.persisted) {
        DiscourseURL.routeTo(this.location.pathname);
      }
    };
  }

  willDestroy() {
    super.willDestroy(...arguments);

    // document.removeEventListener("touchmove", this._debouncedScroll);
    // window.removeEventListener("scroll", this._debouncedScroll);
    window.removeEventListener("resize", this.#onWindowResize);

    this.appEvents.off("post-stream:refresh", this, "_debouncedScroll");
    this.appEvents.off("post-stream:refresh", this, "_refresh");
    this.appEvents.off("post-stream:posted", this, "_posted");

    // disconnect the intersection observers
    this.#currentPostObserver.disconnect();
    this.#currentPostObserver.sconnect();
    this.#viewportObserver.disconnect();
    this.#cloakingObserver.disconnect();
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

    return Math.floor((time2 - time1) / DAY_MS);
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
  isCloaked(post, { above, below }) {
    if (!cloakingEnabled || cloakingPrevented.has(post.id)) {
      return false;
    }

    const height = this.#cloakedPostsHeight[post.id];

    return height && (post.post_number < above || post.post_number > below)
      ? { height }
      : null;
  }

  @bind
  updateIntersectionObservers(_, __, { headerOffset, cloakOffset }) {
    const headerMargin = headerOffset * -1;

    this.#currentPostObserver?.disconnect?.();
    this.#cloakingObserver?.disconnect?.();
    this.#viewportObserver?.disconnect?.();

    this.#currentPostObserver = this.#initializeObserver(
      this.trackCurrentPost,
      {
        rootMargin: `${headerMargin}px 0px 0px 0px`,
        // eslint-disable-next-line no-shadow
        threshold: Array.from({ length: 101 }, (_, i) =>
          Number((i * 0.01).toFixed(2))
        ),
      }
    );

    this.#cloakingObserver = this.#initializeObserver(this.trackCloakedPosts, {
      rootMargin: `${cloakOffset}px 0px`,
      threshold: [0, 1],
    });

    // TODO (glimmer-post-stream) is it enough to track every 5% of the post?
    this.#viewportObserver = this.#initializeObserver(this.trackVisiblePosts, {
      rootMargin: `${headerMargin}px 0px 0px 0px`,
      threshold: [0, 1],
    });

    for (const element of this.observedPostNodes) {
      this.#cloakingObserver.observe(element);
      this.#viewportObserver.observe(element);
    }
  }

  @bind
  registerPostNode(element, [post]) {
    element[POST_MODEL] = post;

    if (!element.classList.contains(CLOAKABLE_CLASS)) {
      element.classList.add(CLOAKABLE_CLASS);
    }

    if (!this.observedPostNodes.has(element)) {
      this.observedPostNodes.add(element);
      this.#cloakingObserver.observe(element);
      this.#viewportObserver.observe(element);
    }
  }

  unregisterPostNode(element) {
    delete element[POST_MODEL];

    this.#cloakingObserver.unobserve(element);
    this.#viewportObserver.unobserve(element);
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
  trackCurrentPost(entry) {
    const { target, intersectionRatio, isIntersecting } = entry;

    if (!isIntersecting) {
      return;
    }

    discourseDebounce(
      this,
      this.#onCurrentPostScrolled,
      { element: target, percent: 1 - intersectionRatio },
      SCROLL_BATCH_INTERVAL_MS
    );
  }

  @bind
  trackCloakedPosts(entry) {
    const { target, isIntersecting } = entry;
    const post = target[POST_MODEL];

    if (!post) {
      return;
    }

    const postNumber = post.post_number;

    if (this.#observedCloakBoundaries.below === null) {
      this.#observedCloakBoundaries.below = postNumber;
    }
    if (this.#observedCloakBoundaries.above === null) {
      this.#observedCloakBoundaries.above = postNumber;
    }

    if (isIntersecting) {
      this.uncloakedPostNumbers.add(postNumber);
      // entering the visibility area
      delete this.#cloakedPostsHeight[post.id];

      if (postNumber < this.#observedCloakBoundaries.above) {
        this.#observedCloakBoundaries.above = postNumber;
      } else if (postNumber > this.#observedCloakBoundaries.below) {
        this.#observedCloakBoundaries.below = postNumber;
      }
    } else {
      this.uncloakedPostNumbers.delete(postNumber);

      let height = target.clientHeight;
      const style = window.getComputedStyle(target);
      height +=
        parseFloat(style.borderTopWidth) + parseFloat(style.borderBottomWidth);
      this.#cloakedPostsHeight[post.id] = height;
      target.style.height = height + "px";

      if (
        postNumber > this.#observedCloakBoundaries.above &&
        postNumber < this.#observedCloakBoundaries.below
      ) {
        if (
          ![...this.uncloakedPostNumbers].some((value) => value <= postNumber)
        ) {
          this.#observedCloakBoundaries.above = postNumber + 1;
        } else {
          this.#observedCloakBoundaries.below = postNumber - 1;
        }
      }
    }

    if (
      this.#observedCloakBoundaries.above !== this.cloakAbove &&
      this.#observedCloakBoundaries.below !== this.cloakBelow
    ) {
      discourseDebounce(
        this,
        this.#updateCloakActiveBoundaries,
        { ...this.#observedCloakBoundaries },
        [...this.uncloakedPostNumbers],
        SCROLL_BATCH_INTERVAL_MS
      );
    }
  }

  @bind
  trackVisiblePosts(entry) {
    const { target, isIntersecting } = entry;
    const post = target[POST_MODEL];

    if (isIntersecting) {
      this.#postsOnScreen[post.post_number] = { post, element: target };
    } else {
      delete this.#postsOnScreen[post.post_number];
    }

    // update the screen tracking information
    discourseDebounce(
      this,
      this.#updateScreenTracking,
      this.#postsOnScreen,
      SCROLL_BATCH_INTERVAL_MS
    );

    // update the information about the boundaries of the posts on screen
    this.#onScreenBoundaries = Object.values(this.#postsOnScreen).reduce(
      (acc, { post: onScreen }) => {
        if (acc.min === null || onScreen.post_number < acc.min) {
          acc.min = onScreen.post_number;
        }

        if (acc.max === null || onScreen.post_number > acc.max) {
          acc.max = onScreen.post_number;
        }

        return acc;
      },
      { min: null, max: null }
    );

    // update the current post to enable fine grained scrolling tracking for it
    this.#updateCurrentPost(
      this.#onScreenBoundaries.min !== null
        ? this.#postsOnScreen[this.#onScreenBoundaries.min]?.element
        : null
    );
  }

  @action
  loadMoreAbove(post) {
    this.args.topVisibleChanged({
      post,
      refresh: () => {
        const refreshedElem = this.#postsOnScreen[post.post_number]?.element;

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

  #onCurrentPostChanged(event) {
    this.args.currentPostChanged(event);
  }

  #onCurrentPostScrolled({ element, ...event }) {
    if (element !== this.#currentPostElement) {
      return;
    }

    this.args.currentPostScrolled(event);
  }

  #onWindowResize(event) {
    discourseDebounce(this, this.#updateCloakOffset, event, RESIZE_DEBOUNCE_MS);
  }

  #updateCloakActiveBoundaries({ above, below }) {
    this.cloakAbove = above;
    this.cloakBelow = below;

    schedule("afterRender", () => {
      requestAnimationFrame(() => {
        document
          .querySelectorAll(CLOAKABLE_CLASS_SELECTOR)
          .forEach((element) => (element.style.height = ""));
      });
    });
  }

  #updateCloakOffset() {
    this.cloakOffset = Math.ceil(window.innerHeight * SLACK_FACTOR);
  }

  #updateCurrentPost(newElement) {
    if (this.#currentPostElement === newElement) {
      return;
    }

    if (this.#currentPostElement) {
      this.#currentPostObserver.unobserve(this.#currentPostElement);
    }

    const currentPost = this.#currentPostElement?.[POST_MODEL];
    const newPost = newElement?.[POST_MODEL];

    if (currentPost !== newPost) {
      discourseDebounce(
        this,
        this.#onCurrentPostChanged,
        { post: newPost },
        SCROLL_BATCH_INTERVAL_MS
      );
    }

    this.#currentPostElement = newElement;

    if (newElement) {
      this.#currentPostObserver.observe(newElement);
    }
  }

  #updateScreenTracking(postsOnScreen) {
    const onScreenPostsNumbers = [];
    const readPostNumbers = [];

    Object.values(postsOnScreen).forEach(({ post }) => {
      onScreenPostsNumbers.push(post.post_number);

      if (post.read) {
        readPostNumbers.push(post.post_number);
      }
    });

    this.screenTrack.setOnscreen(onScreenPostsNumbers, readPostNumbers);
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
              as |PostComponent|
            }}
              <PostComponent
                @cloaked={{this.isCloaked
                  post
                  above=this.cloakAbove
                  below=this.cloakBelow
                }}
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
                {{didInsert this.registerPostNode post}}
                {{didUpdate this.registerPostNode post}}
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
