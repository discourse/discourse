import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { concat, fn, get, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import willDestroy from "@ember/render-modifiers/modifiers/will-destroy";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { TrackedSet } from "@ember-compat/tracked-built-ins";
import { and, not } from "truth-helpers";
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

const DAY_MS = 1000 * 60 * 60 * 24;
const POST_MODEL = Symbol("POST");
const RESIZE_DEBOUNCE_MS = 100;
const SCROLL_BATCH_INTERVAL_MS = 10;
const SLACK_FACTOR = 1;

// change this value to true to debug the eyeline position
const DEBUG_EYELINE = false;

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

  #bottomBoundaryElement;
  #eyelineDebugElement;
  #cloakedPostsHeight = {};
  #cloakingObserver;
  #currentPostElement;
  #observedPostNodes = new Set();
  #postsOnScreen = {};
  #uncloakedPostNumbers = new Set();
  #viewportObserver;
  #wrapperElement;

  constructor() {
    super(...arguments);

    this.#updateCloakOffset();
    this.#setupEventListeners();
    this.#setupEyelineDebugElement();
  }

  willDestroy() {
    super.willDestroy(...arguments);

    // remove the event listeners
    this.#setupEventListeners(false);
    // remove the eyeline debug element
    this.#setupEyelineDebugElement(false);

    // disconnect the intersection observers
    this.#viewportObserver?.disconnect();
    this.#cloakingObserver?.disconnect();
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
    const time1 = post1 ? new Date(post1.createdAt).getTime() : null;
    const time2 = post2 ? new Date(post2.createdAt).getTime() : null;

    if (!time1 || !time2) {
      return null;
    }

    return Math.floor((time2 - time1) / DAY_MS);
  }

  @bind
  getCloakingData(post, { above, below }) {
    if (!cloakingEnabled || !post || cloakingPrevented.has(post.id)) {
      return null;
    }

    const height = this.#cloakedPostsHeight[post.id];

    return height && (post.post_number < above || post.post_number > below)
      ? { active: true, style: htmlSafe("height: " + height + "px;") }
      : { active: false };
  }

  @bind
  registerPostNode(element, [post]) {
    element[POST_MODEL] = post;

    if (!this.#observedPostNodes.has(element)) {
      this.#observedPostNodes.add(element);
      this.#cloakingObserver?.observe(element);
      this.#viewportObserver?.observe(element);
    }
  }

  @bind
  setWrapperElement(element) {
    this.#wrapperElement = element;

    schedule("afterRender", () => {
      this.#scrollTriggered();
    });
  }

  @bind
  setBottomBoundaryElement(element) {
    this.#bottomBoundaryElement = element;
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
  trackCloakedPosts(entry) {
    const { target, isIntersecting } = entry;
    const post = target[POST_MODEL];

    if (!post) {
      return;
    }

    const postNumber = post.post_number;

    if (isIntersecting) {
      this.#uncloakedPostNumbers.add(postNumber);
      // entering the visibility area
      delete this.#cloakedPostsHeight[post.id];
    } else {
      this.#uncloakedPostNumbers.delete(postNumber);

      let height = target.clientHeight;
      const style = window.getComputedStyle(target);
      height +=
        parseFloat(style.borderTopWidth) + parseFloat(style.borderBottomWidth);
      this.#cloakedPostsHeight[post.id] = height;
    }

    discourseDebounce(
      this,
      this.#updateCloakBoundaries,
      SCROLL_BATCH_INTERVAL_MS
    );
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
      SCROLL_BATCH_INTERVAL_MS
    );

    this.#scrollTriggered();
  }

  @bind
  updateIntersectionObservers(_, __, { headerOffset, cloakOffset }) {
    const headerMargin = headerOffset * -1;

    this.#cloakingObserver?.disconnect();
    this.#viewportObserver?.disconnect();

    this.#cloakingObserver = this.#initializeObserver(this.trackCloakedPosts, {
      rootMargin: `${cloakOffset}px 0px`,
      threshold: [0, 1],
    });

    this.#viewportObserver = this.#initializeObserver(this.trackVisiblePosts, {
      rootMargin: `${headerMargin}px 0px 0px 0px`,
      threshold: [0, 1],
    });

    for (const element of this.#observedPostNodes) {
      this.#cloakingObserver.observe(element);
      this.#viewportObserver.observe(element);
    }
  }

  @bind
  unregisterPostNode(element) {
    delete element[POST_MODEL];

    if (this.#observedPostNodes.has(element)) {
      this.#observedPostNodes.delete(element);
      this.#cloakingObserver?.unobserve(element);
      this.#viewportObserver?.unobserve(element);
    }
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

  @action
  onScroll() {
    discourseDebounce(this, this.#scrollTriggered, SCROLL_BATCH_INTERVAL_MS);
  }

  @action
  onWindowResize(event) {
    discourseDebounce(
      this,
      this.#windowResizeTriggered,
      event,
      RESIZE_DEBOUNCE_MS
    );
  }

  #calculateEyelineViewportOffset() {
    // Get viewport and scroll data
    const viewportHeight = window.innerHeight;
    const scrollPosition = window.scrollY;
    const documentHeight = Math.max(
      document.body.scrollHeight,
      document.documentElement.scrollHeight
    );

    // Calculate boundaries
    const topBoundary = Math.max(
      this.header.headerOffset,
      this.#wrapperElement.getBoundingClientRect().top
    );
    const bottomBoundary =
      this.#bottomBoundaryElement?.getBoundingClientRect()?.top ??
      viewportHeight;

    // Calculate distance from topic bottom to document bottom
    const topicBottomAbsolute = bottomBoundary + scrollPosition;
    const distanceToBottom = documentHeight - topicBottomAbsolute;

    // Calculate scroll area and progress
    const scrollableArea = Math.min(
      viewportHeight,
      distanceToBottom,
      documentHeight - viewportHeight
    );
    const remainingScroll = documentHeight - viewportHeight - scrollPosition;
    const progress =
      scrollableArea > 0
        ? 1 - Math.min(1, Math.max(0, remainingScroll / scrollableArea))
        : 1;

    // Return interpolated position between boundaries based on progress
    return topBoundary + progress * (bottomBoundary - topBoundary);
  }

  #currentPostWasChanged(event) {
    this.args.currentPostChanged(event);
  }

  #currentPostWasScrolled({ element, ...event }) {
    if (element !== this.#currentPostElement) {
      return;
    }

    this.args.currentPostScrolled(event);
  }

  #findPostMatchingEyeline(eyeLineOffset) {
    let target, percentScrolled;
    for (const { element } of Object.values(this.#postsOnScreen)) {
      const { top, bottom } = element.getBoundingClientRect();

      if (eyeLineOffset >= top && eyeLineOffset <= bottom) {
        target = element;
        percentScrolled = (eyeLineOffset - top) / (bottom - top);
        break;
      }
    }

    if (target) {
      this.#updateCurrentPost(target);
      this.#currentPostWasScrolled({
        element: target,
        percent: percentScrolled,
      });
    }
  }

  #initializeObserver(callback, { rootMargin, threshold }) {
    return new IntersectionObserver(
      (entries) => {
        entries.forEach(callback);
      },
      { threshold, rootMargin, root: document }
    );
  }

  #scrollTriggered() {
    const eyelineOffset = this.#calculateEyelineViewportOffset();

    discourseDebounce(
      this,
      this.#findPostMatchingEyeline,
      eyelineOffset,
      SCROLL_BATCH_INTERVAL_MS
    );

    if (DEBUG_EYELINE) {
      this.#updateEyelineDebugElementPosition(eyelineOffset);
    }
  }

  #setupEventListeners(addListeners = true) {
    if (!addListeners) {
      window.removeEventListener("resize", this.onWindowResize);
      window.removeEventListener("scroll", this.onScroll);
      window.removeEventListener("touchmove", this.onScroll);

      return;
    }

    const opts = {
      passive: true,
    };

    window.addEventListener("resize", this.onWindowResize, opts);
    window.addEventListener("scroll", this.onScroll, opts);
    window.addEventListener("touchmove", this.onScroll, opts);

    window.onpageshow = function (event) {
      if (event.persisted) {
        DiscourseURL.routeTo(this.location.pathname);
      }
    };
  }

  #setupEyelineDebugElement(addElement = true) {
    if (DEBUG_EYELINE) {
      if (!addElement) {
        this.#eyelineDebugElement.remove();

        return;
      }

      this.#eyelineDebugElement = document.createElement("div");
      this.#eyelineDebugElement.classList.add("post-stream__bottom-eyeline");
      document.body.prepend(this.#eyelineDebugElement);
    }
  }

  #updateCloakBoundaries() {
    const uncloackedPostNumbers = Array.from(this.#uncloakedPostNumbers);

    let above = uncloackedPostNumbers[0] || 0;
    let below = above;
    for (let i = 1; i < uncloackedPostNumbers.length; i++) {
      const postNumber = uncloackedPostNumbers[i];
      above = Math.min(postNumber, above);
      below = Math.max(postNumber, below);
    }

    // requesting an animation frame to update the cloaking boundaries prevents Chrome from logging
    // [Violation] 'setTimeout' handler took <N>ms when scrolling fast
    requestAnimationFrame(() => {
      this.cloakAbove = above;
      this.cloakBelow = below;
    });
  }

  #updateCloakOffset() {
    this.cloakOffset = Math.ceil(window.innerHeight * SLACK_FACTOR);
  }

  @bind
  #updateEyelineDebugElementPosition(viewportOffset) {
    if (this.#eyelineDebugElement) {
      Object.assign(this.#eyelineDebugElement.style, {
        position: "fixed",
        top: `${viewportOffset}px`,
        width: "100%",
        border: "1px solid red",
        opacity: 1,
        zIndex: 999999,
      });
    }
  }

  #updateCurrentPost(newElement) {
    if (this.#currentPostElement === newElement) {
      return;
    }

    const currentPost = this.#currentPostElement?.[POST_MODEL];
    const newPost = newElement?.[POST_MODEL];

    this.#currentPostElement = newElement;

    if (currentPost !== newPost) {
      this.#currentPostWasChanged({ post: newPost });
    }
  }

  #updateScreenTracking() {
    const onScreenPostsNumbers = [];
    const readPostNumbers = [];

    Object.values(this.#postsOnScreen).forEach(({ post }) => {
      onScreenPostsNumbers.push(post.post_number);

      if (post.read) {
        readPostNumbers.push(post.post_number);
      }
    });

    this.screenTrack.setOnscreen(onScreenPostsNumbers, readPostNumbers);
  }

  #windowResizeTriggered(event) {
    this.#updateCloakOffset(event);
  }

  <template>
    <ConditionalLoadingSpinner @condition={{@postStream.loadingAbove}} />
    <div
      class="post-stream"
      {{didInsert this.setWrapperElement}}
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
      {{#if (and (not @postStream.loadingAbove) @postStream.canPrependMore)}}
        <LoadMore @action={{fn this.loadMoreAbove this.firstAvailablePost}} />
      {{/if}}

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
              (this.getCloakingData
                post above=this.cloakAbove below=this.cloakBelow
              )
              as |PostComponent cloakingData|
            }}
              <PostComponent
                id={{concat "post_" post.post_number}}
                class={{if cloakingData.active "post-stream--cloaked"}}
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

      {{#unless @postStream.loadingBelow}}
        {{#if @postStream.canAppendMore}}
          <LoadMore @action={{fn this.loadMoreBelow this.lastAvailablePost}} />
        {{else}}
          <div
            class="post-stream__bottom-boundary"
            {{didInsert this.setBottomBoundaryElement}}
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
