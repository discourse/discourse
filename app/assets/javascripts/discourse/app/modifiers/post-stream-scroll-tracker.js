import { schedule } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import DiscourseURL from "discourse/lib/url";

const POST_MODEL = Symbol("POST");
const RESIZE_DEBOUNCE_MS = 100;
const SCROLL_BATCH_INTERVAL_MS = 10;
const SLACK_FACTOR = 1;

// change this value to true to debug the eyeline position
const DEBUG_EYELINE = true;

let cloakingEnabled = true;
const cloakingPrevented = new Set();

export function disableCloaking() {
  cloakingEnabled = false;
}

export function preventCloaking(postId) {
  cloakingPrevented.add(postId);
}

export default class PostStreamScrollTracker {
  #bottomBoundaryElement;
  #cloakOffset;
  #cloakedPostsHeight = {};
  #cloakingObserver;
  #currentPostChanged;
  #currentPostElement;
  #currentPostScrolled;
  #eyelineDebugElement;
  #headerOffset;
  #observedPostNodes = new Set();
  #postsOnScreen = {};
  #screenTrackService;
  #setCloakingBoundaries;
  #uncloakedPostNumbers = new Set();
  #viewportObserver;
  #wrapperElement;

  #registerBottomBoundary = modifier((element) => {
    this.#bottomBoundaryElement = element;

    // clean-up
    return () => {
      this.#bottomBoundaryElement = null;
    };
  });

  #registerPost = modifier((element, [post]) => {
    element[POST_MODEL] = post;

    if (!this.#observedPostNodes.has(element)) {
      this.#observedPostNodes.add(element);
      this.#cloakingObserver?.observe(element);
      this.#viewportObserver?.observe(element);
    }

    // clean-up
    return () => {
      delete element[POST_MODEL];

      if (this.#observedPostNodes.has(element)) {
        this.#observedPostNodes.delete(element);
        this.#cloakingObserver?.unobserve(element);
        this.#viewportObserver?.unobserve(element);
      }
    };
  });

  #setup = modifier(
    (
      element,
      _,
      {
        currentPostChanged,
        currentPostScrolled,
        headerOffset,
        screenTrack,
        setCloakingBoundaries,
      }
    ) => {
      this.#wrapperElement = element;

      this.#currentPostChanged = currentPostChanged;
      this.#currentPostScrolled = currentPostScrolled;
      this.#headerOffset = headerOffset;
      this.#screenTrackService = screenTrack;
      this.#setCloakingBoundaries = setCloakingBoundaries;

      this.#updateCloakOffset();
      this.#setupEventListeners();

      // intersection observers
      this.#resetViewportObservers();
      // eyeline
      this.#setupEyelineDebugElement();

      schedule("afterRender", () => {
        this.#scrollTriggered();
      });

      // clean-up
      return () => {
        this.#cloakingObserver?.disconnect();
        this.#viewportObserver?.disconnect();

        // clear event listeners
        this.#setupEventListeners(false);
        // remove the eyeline debug element
        this.#setupEyelineDebugElement(false);
      };
    }
  );

  destroy() {
    // disconnect the intersection observers
    this.#viewportObserver?.disconnect();
    this.#cloakingObserver?.disconnect();

    // clear DOM references
    this.#observedPostNodes.clear();
  }

  get postsOnScreen() {
    return this.#postsOnScreen;
  }

  get registerBottomBoundary() {
    return this.#registerBottomBoundary;
  }

  get registerPost() {
    return this.#registerPost;
  }

  get setup() {
    return this.#setup;
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
  onScroll() {
    discourseDebounce(this, this.#scrollTriggered, SCROLL_BATCH_INTERVAL_MS);
  }

  @bind
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
      this.#headerOffset,
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
    this.#currentPostChanged(event);
  }

  #currentPostWasScrolled({ element, ...event }) {
    if (element !== this.#currentPostElement) {
      return;
    }

    this.#currentPostScrolled(event);
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

  #resetViewportObservers() {
    this.#cloakingObserver?.disconnect();
    this.#viewportObserver?.disconnect();

    const headerMargin = this.#headerOffset * -1;

    this.#cloakingObserver = this.#initializeObserver(this.trackCloakedPosts, {
      rootMargin: `${this.#cloakOffset}px 0px`,
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

  #updateCloakBoundaries() {
    const uncloackedPostNumbers = Array.from(this.#uncloakedPostNumbers);

    let above = uncloackedPostNumbers[0] || 0;
    let below = above;
    for (let i = 1; i < uncloackedPostNumbers.length; i++) {
      const postNumber = uncloackedPostNumbers[i];
      above = Math.min(postNumber, above);
      below = Math.max(postNumber, below);
    }

    this.#setCloakingBoundaries(above, below);
  }

  #updateCloakOffset() {
    const newOffset = Math.ceil(window.innerHeight * SLACK_FACTOR);

    if (newOffset === this.#cloakOffset) {
      return false;
    }

    this.#cloakOffset = Math.ceil(window.innerHeight * SLACK_FACTOR);

    return true;
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

    this.#screenTrackService.setOnscreen(onScreenPostsNumbers, readPostNumbers);
  }

  #windowResizeTriggered() {
    if (this.#updateCloakOffset()) {
      this.#resetViewportObservers();
    }
  }

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
}
