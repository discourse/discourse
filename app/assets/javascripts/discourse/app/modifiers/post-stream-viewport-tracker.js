import { cancel, schedule } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
import { isTesting } from "discourse/lib/environment";
import DiscourseURL from "discourse/lib/url";

/**
 * PostStreamViewportTracker
 * -----------------------
 *
 * This class implements a performance optimization system for the post stream by
 * tracking which posts are visible on screen and implementing a "cloaking" mechanism
 * that hides posts far from the viewport.
 *
 * How Cloaking Works:
 * -------------------
 * 1. Intersection Observers track which posts are visible in the viewport
 * 2. Posts that are far from the viewport (beyond the cloakOffset) are "cloaked"
 * 3. Cloaked posts are replaced with placeholder divs of the same height
 * 4. As the user scrolls, posts are dynamically uncloaked when they approach the viewport
 * 5. This significantly reduces DOM nodes and improves performance for long topics
 *
 * The system also tracks the current post being viewed using an "eyeline" - a
 * calculated position in the viewport that determines which post is considered current
 * and the percentage of the current post that is scrolled.
 */

// Debounce time for resize events in milliseconds
const RESIZE_DEBOUNCE_MS = 100;

// Debounce time for batching scroll events in milliseconds
const SCROLL_BATCH_INTERVAL_MS = 10;

// Factor to determine how far beyond viewport to keep posts uncloaked.
// A lower number implies that fewer posts are uncloaked at any given time, and as a consequence, the users will notice
// posts uncloaking more frequently as they scroll. On the other hand, big jumps will be rendered fast.
// A higher number implies that there will be more posts uncloaked. That reduces the frequency which users will notice
// uncloaking while scrolling. However, big jumps will need to rerender many posts, and that will be noticeable with the
// system feeling sluggish.
const SLACK_FACTOR = 1;

// Number of pixels of intersection required before a post is uncloaked when entering the visibility area.
// If a post intersects by at least the amount of pixels specified, it will be uncloaked even if the ratio
// threshold is not met
const UNCLOAKING_HYSTERESIS_THRESHOLD_PX = 5;

// Percentage of intersection required before a post is uncloaked when entering the visibility area.
// Post must have at least the specified ratio of its area intersecting to be uncloaked.
// Works together with pixel threshold - whichever condition is met first will trigger uncloaking
const UNCLOAKING_HYSTERESIS_RATIO = 0.05;

// Set to true to visualize the eyeline position with a red line
const DEBUG_EYELINE = false;

// Global flag to enable/disable the cloaking mechanism
let cloakingEnabled = true;

/**
 * Globally disables the cloaking mechanism for all posts
 *
 * @returns {void}
 * @example
 * disableCloaking(); // Disables cloaking for testing
 */
export function disableCloaking() {
  cloakingEnabled = false;
}

// Dictionary containing the set of post IDs that should never be cloaked.
// The topicId is used to clear the set when the topic changes.
const cloakingPrevented = { topicId: null, posts: new Set() };

/**
 * Prevents a specific post from being cloaked
 * Useful for posts that need to remain visible regardless of scroll position because removing
 * the DOM nodes can cause side effects, e.g., a video playing
 *
 * @param {number} postId - The ID of the post to prevent from cloaking
 * @param {boolean} [prevent=true] - Whether to prevent cloaking (true) or allow it (false)
 * @returns {void}
 * @example
 * preventCloaking(123, true); // Prevents post 123 from being cloaked
 * preventCloaking(123, false); // Allows post 123 to be cloaked again
 */
export function preventCloaking(postId, prevent = true) {
  if (prevent) {
    cloakingPrevented.posts.add(postId);
  } else {
    cloakingPrevented.posts.delete(postId);
  }
}

/**
 * A WeakMap storing post models for DOM elements.
 * Maps elements in the post stream to their corresponding post models.
 * Uses WeakMap to avoid memory leaks when elements are removed from the DOM.
 *
 * @type {WeakMap<HTMLElement, Object>}
 */
const elementsToPost = new WeakMap();

/**
 * PostStreamViewportTracker manages viewport tracking and cloaking for post streams.
 * This class provides performance optimization by tracking visible posts and implementing
 * a cloaking mechanism that replaces off-screen posts with placeholder elements.
 */
export default class PostStreamViewportTracker {
  /**
   * Reference to the bottom boundary element used for eyeline calculations
   * @type {HTMLElement|null}
   * @private
   */
  #bottomBoundaryElement;

  /**
   * Distance beyond viewport to keep posts uncloaked (calculated from viewport height)
   * @type {number}
   * @private
   */
  #cloakOffset;

  /**
   * Map of post IDs to their styles when cloaked
   * Used to maintain correct scroll position when posts are cloaked
   * @type {Object<number, {height: number, margin: string}>}
   * @private
   */
  #cloakedPostsStyle = {};

  /**
   * IntersectionObserver that tracks which posts should be cloaked/uncloaked
   * @type {IntersectionObserver|null}
   * @private
   */
  #cloakingObserver;

  /**
   * Callback function to notify when the current post changes
   * @type {Function|null}
   * @private
   */
  #currentPostChanged;

  /**
   * Reference to the DOM element of the current post being viewed
   * @type {HTMLElement|null}
   * @private
   */
  #currentPostElement;

  /**
   * Callback function to notify when the scroll position within the current post changes
   * @type {Function|null}
   * @private
   */
  #currentPostScrolled;

  /**
   * Debug element used to visualize the eyeline position
   * @type {HTMLElement|null}
   * @private
   */
  #eyelineDebugElement;

  /**
   * Offset from the top of the viewport for the site header
   * Used in calculations to determine visible posts
   * @type {number}
   * @private
   */
  #headerOffset;

  /**
   * Set of posts' DOM nodes being observed by the intersection observers
   * @type {Set<HTMLElement>}
   * @private
   */
  #observedPostElements = new Set();

  /**
   * Map of post numbers to their post models and DOM elements that are currently on screen
   * Used to track which posts are visible in the viewport for eyeline calculations and screen tracking
   * @type {Object<number, {post: Object, element: HTMLElement}>}
   * @private
   */
  #postsOnScreen = {};

  /**
   * Map to store scheduled/debounced timers for various tracker functions
   * Used to track and cancel pending timers when the component is destroyed
   * @type {Map<Function, number>}
   * @private
   */
  #scheduledTimers = new Map();

  /**
   * Reference to the screen track service for tracking post visibility
   * @type {Object|null}
   * @private
   */
  #screenTrackService;

  /**
   * Callback function to update the cloaking boundaries in the parent component
   * @type {Function|null}
   * @private
   */
  #setCloakingBoundaries;

  /**
   * Set of post numbers that are currently uncloaked (visible or near viewport)
   * @type {Set<number>}
   * @private
   */
  #uncloakedPostNumbers = new Set();

  /**
   * IntersectionObserver that tracks which posts are visible in the viewport
   * @type {IntersectionObserver|null}
   * @private
   */
  #viewportObserver;

  /**
   * Reference to the wrapper element containing all posts
   * @type {HTMLElement|null}
   * @private
   */
  #wrapperElement;

  /**
   * Ember modifier that registers the bottom boundary element for eyeline calculations
   * This element marks the end of the post stream and is used to determine the eyeline position
   *
   * @type {Modifier}
   * @param {HTMLElement} element - The element to register as the bottom boundary
   * @param {Array} _ - Modifier positional params (unused)
   * @param {Object} trackedArgs - Additional tracked arguments that trigger cleanup when changed
   * @returns {Function} Cleanup function that removes the reference when the element is destroyed
   * @private
   */
  #registerBottomBoundary = modifier((element, _, trackedArgs) => {
    this.#bottomBoundaryElement = element;

    // Consume the remaining properties to track them and run the cleanup functions when their values change
    // https://github.com/emberjs/ember.js/issues/19277
    trackedArgs && Object.values(trackedArgs);

    // clean-up
    return () => {
      this.#bottomBoundaryElement = null;
    };
  });

  /**
   * Ember modifier that registers a post element for tracking
   * Attaches the post model to the element and adds it to the intersection observers
   *
   * @type {Modifier}
   * @param {HTMLElement} element - The post element to register
   * @param {Array} [post] - Array containing the post model associated with the element
   * @returns {Function} Cleanup function that removes observers when the element is destroyed
   * @private
   */
  #registerPost = modifier((element, [post]) => {
    elementsToPost.set(element, post);

    if (!this.#observedPostElements.has(element)) {
      this.#observedPostElements.add(element);
      this.#cloakingObserver?.observe(element);
      this.#viewportObserver?.observe(element);
    }

    // clean-up
    return () => {
      elementsToPost.delete(element);

      if (this.#observedPostElements.has(element)) {
        this.#observedPostElements.delete(element);
        this.#cloakingObserver?.unobserve(element);
        this.#viewportObserver?.unobserve(element);
      }
    };
  });

  /**
   * Main setup modifier that initializes the scroll tracker
   * Sets up event listeners, intersection observers, and initializes tracking
   *
   * @type {Modifier}
   * @param {HTMLElement} element - The wrapper element containing all posts
   * @param {Array} _ - Modifier positional params (unused)
   * @param {Object} options - Named arguments for the modifier
   * @param {Function} options.currentPostChanged - Callback when current post changes
   * @param {Function} options.currentPostScrolled - Callback when scroll position within current post changes
   * @param {number} options.headerOffset - Offset from top of viewport for site header
   * @param {Object} options.screenTrack - Screen tracking service
   * @param {Function} options.setCloakingBoundaries - Callback to update cloaking boundaries
   * @param {number} options.topicId - ID of the current topic
   * @param {Object} options.trackedArgs - Additional tracked arguments that trigger cleanup when changed
   * @returns {Function} Cleanup function that removes observers, event listeners and clears state
   * @private
   */
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
        topicId,
        ...trackedArgs
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

      // clear the list of posts with cloaking prevented when the topic changes
      if (cloakingPrevented.topicId !== topicId) {
        cloakingPrevented.topicId = topicId;
        cloakingPrevented.posts.clear();
      }

      // consume the remaining properties to track them and run the cleanup functions when their values change
      // https://github.com/emberjs/ember.js/issues/19277
      trackedArgs && Object.values(trackedArgs);

      schedule("afterRender", () => {
        // forces updates performed when the scroll is triggered to be performed after the initial rendering
        this.#scrollTriggered(true);
      });

      // cleanup
      return () => {
        // clear observers
        this.#cloakingObserver?.disconnect();
        this.#viewportObserver?.disconnect();

        // clear event listeners
        this.#setupEventListeners(false);
        // remove the eyeline debug element
        this.#setupEyelineDebugElement(false);

        // clear collections
        this.#cloakedPostsStyle = {};
        this.#postsOnScreen = {};
        this.#uncloakedPostNumbers.clear();

        // clear instance properties
        this.#currentPostElement = null;
      };
    }
  );

  /**
   * Cleans up resources when the tracker is destroyed
   * Disconnects intersection observers and clears DOM references
   * @returns {void}
   */
  destroy() {
    // cancel scheduled timers
    for (const timer of this.#scheduledTimers.values()) {
      cancel(timer);
    }

    // disconnect the intersection observers
    this.#viewportObserver?.disconnect();
    this.#cloakingObserver?.disconnect();

    // clear DOM references
    this.#observedPostElements.clear();

    // clear the set of posts with cloaking prevented
    cloakingPrevented.topicId = null;
    cloakingPrevented.posts.clear();
  }

  /**
   * Returns a map of post numbers to their post models and DOM elements that are currently on screen
   * @returns {Object<number, {post: Object, element: HTMLElement}>} Map of visible posts
   */
  get postsOnScreen() {
    return this.#postsOnScreen;
  }

  /**
   * Returns the modifier for registering the bottom boundary element
   * @returns {Modifier} The bottom boundary registration modifier
   */
  get registerBottomBoundary() {
    return this.#registerBottomBoundary;
  }

  /**
   * Returns the modifier for registering post elements
   * @returns {Modifier} The post registration modifier
   */
  get registerPost() {
    return this.#registerPost;
  }

  /**
   * Returns the main setup modifier
   * @returns {Modifier} The setup modifier
   */
  get setup() {
    return this.#setup;
  }

  /**
   * Determines if a post should be cloaked based on its position relative to the viewport boundaries
   * Returns an object containing cloaking state and optional height style when cloaking is active
   *
   * @param {Object} post - The post model
   * @param {Object} options - Cloaking boundary options
   * @param {number} options.above - The minimum post number to keep visible
   * @param {number} options.below - The maximum post number to keep visible
   * @returns {Object} Object with active boolean and optional style string
   *                   {active: boolean, style?: string}
   */
  @bind
  getCloakingData(post, { above, below }) {
    if (
      !cloakingEnabled ||
      !post ||
      cloakingPrevented.posts.has(post.id) ||
      this.#postsOnScreen[post.post_number]
    ) {
      return { active: false };
    }

    const style = this.#cloakedPostsStyle[post.id];
    if (style && (post.post_number < above || post.post_number > below)) {
      const { height, margin } = style;

      // we're using getBoundingClientRect().height to get the element height before cloaking.
      // we need to ensure the box-model is border-box to ensure the height is matched with the original
      // element height
      return {
        active: true,
        style: htmlSafe(
          `height:${height}px !important;` +
            `margin:${margin} !important;` +
            "box-sizing: border-box !important;"
        ),
      };
    }

    return { active: false };
  }

  /**
   * Intersection observer callback for tracking which posts should be cloaked
   * Updates the cloaking state based on post visibility
   *
   * @param {IntersectionObserverEntry} entry - The intersection observer entry
   * @returns {void}
   */
  @bind
  trackCloakedPosts(entry) {
    const { target, isIntersecting, intersectionRect, intersectionRatio } =
      entry;
    const post = elementsToPost.get(target);

    if (!post) {
      return;
    }

    const postNumber = post.post_number;

    if (isIntersecting) {
      // Uncloaks a post if either: 1) it has a significant portion (UNCLOAKING_HYSTERESIS_RATIO)
      // visible and at least 1px height intersection, or 2) it intersects by at least
      // UNCLOAKING_HYSTERESIS_THRESHOLD_PX pixels height-wise. This dual-condition hysteresis
      // prevents rapid cloaking/uncloaking causing layout shifts and flickering when posts are near visibility
      // thresholds.
      if (
        (intersectionRect.height >= 1 &&
          intersectionRatio >= UNCLOAKING_HYSTERESIS_RATIO) ||
        intersectionRect.height >= UNCLOAKING_HYSTERESIS_THRESHOLD_PX
      ) {
        // entering the visibility area
        this.#uncloakedPostNumbers.add(postNumber);
        delete this.#cloakedPostsStyle[post.id];
      }
    } else {
      // entering the cloaking area
      this.#uncloakedPostNumbers.delete(postNumber);

      // saves the current post height to prevent jumps while scrolling with existing cloaked posts
      // we are using `getBoundingClientRect().height` because the element height is a floating number and
      // `element.offsetHeight` returns an integer, which causes rounding error issues in the post tracking
      // `getBoundingClientRect()` also ensures that the padding/border were considered
      this.#cloakedPostsStyle[post.id] = {
        height: target.getBoundingClientRect().height,
        margin: getComputedStyle(target).margin,
      };
    }

    // update the cloaking boundaries
    this.#scheduledTimers.set(
      this.#updateCloakBoundaries,
      discourseDebounce(
        this,
        this.#updateCloakBoundaries,
        SCROLL_BATCH_INTERVAL_MS
      )
    );
  }

  /**
   * Intersection observer callback for tracking which posts are visible in the viewport
   * Updates the postsOnScreen map, triggers screen tracking updates, and calls the scroll handler
   * to update the current post and eyeline position
   *
   * @param {IntersectionObserverEntry} entry - The intersection observer entry
   * @returns {void}
   */
  @bind
  trackVisiblePosts(entry) {
    const { target, isIntersecting } = entry;
    const post = elementsToPost.get(target);

    if (isIntersecting) {
      // entered the viewport
      this.#postsOnScreen[post.post_number] = { post, element: target };
    } else {
      // exited the viewport
      delete this.#postsOnScreen[post.post_number];
    }

    // update the screen tracking information
    this.#scheduledTimers.set(
      this.#updateScreenTracking,
      discourseDebounce(
        this,
        this.#updateScreenTracking,
        SCROLL_BATCH_INTERVAL_MS
      )
    );

    // forces updates performed when the scroll is triggered
    this.#scrollTriggered();
  }

  /**
   * Event handler for scroll events
   * Debounces scroll events to avoid performance issues
   * @returns {void}
   */
  @bind
  onScroll() {
    this.#scheduledTimers.set(
      this.#scrollTriggered,
      discourseDebounce(this, this.#scrollTriggered, SCROLL_BATCH_INTERVAL_MS)
    );
  }

  /**
   * Event handler for window resize events
   * Debounces resize events and updates cloaking boundaries
   *
   * @param {Event} event - The resize event
   * @returns {void}
   */
  @bind
  onWindowResize(event) {
    this.#scheduledTimers.set(
      this.#windowResizeTriggered,
      discourseDebounce(
        this,
        this.#windowResizeTriggered,
        event,
        RESIZE_DEBOUNCE_MS
      )
    );
  }

  /**
   * Gets the testing wrapper element for test environment
   * @private
   * @returns {HTMLElement} The ember-testing container element
   */
  get #testWrapperElement() {
    return document.getElementById("ember-testing");
  }

  /**
   * Gets the total document height, accounting for test environment
   * @private
   * @returns {number} The total scrollable height of the document
   */
  get #documentHeight() {
    return isTesting()
      ? this.#testWrapperElement.scrollHeight
      : Math.max(
          document.body.scrollHeight,
          document.documentElement.scrollHeight
        );
  }

  /**
   * Gets the viewport height, accounting for test environment
   * @private
   * @returns {number} The height of the viewport
   */
  get #viewportHeight() {
    return isTesting()
      ? this.#testWrapperElement.offsetHeight
      : window.innerHeight;
  }

  /**
   * Gets the current scroll position, accounting for test environment
   * @private
   * @returns {number} The current vertical scroll position
   */
  get #scrollPosition() {
    return isTesting() ? this.#testWrapperElement.scrollTop : window.scrollY;
  }

  /**
   * Gets the top boundary position for post visibility calculations
   * In production, accounts for header offset if the wrapper element top is less than header offset
   * @private
   * @returns {number} The top boundary position in viewport coordinates
   */
  get #topBoundary() {
    return isTesting()
      ? this.#wrapperElement.getBoundingClientRect().top
      : Math.max(
          this.#headerOffset,
          this.#wrapperElement.getBoundingClientRect().top
        );
  }

  /**
   * Calculates the position of the "eyeline" - the horizontal line in the viewport
   * that determines which post is considered the current post
   *
   * The eyeline position is dynamically calculated based on scroll position and
   * moves from the top of the viewport (when at the beginning of the topic)
   * to the bottom of the viewport (when at the end of the topic)
   *
   * @private
   * @returns {number} The vertical offset of the eyeline in viewport coordinates
   */
  #calculateEyelineViewportOffset() {
    // Get viewport and scroll data
    const viewportHeight = this.#viewportHeight;
    const scrollPosition = this.#scrollPosition;
    const documentHeight = this.#documentHeight;

    // Calculate boundaries
    const topBoundary = this.#topBoundary;
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

  /**
   * Notifies the parent component that the current post has changed
   *
   * @private
   * @param {Object} event - Event data containing the new current post
   * @returns {void}
   */
  #currentPostWasChanged(event) {
    this.#currentPostChanged(event);
  }

  /**
   * Notifies the parent component about scroll position changes within the current post
   * Only triggers if the element matches the current post element
   *
   * @private
   * @param {Object} params - Parameters containing element and scroll data
   * @param {HTMLElement} params.element - The post element
   * @returns {void}
   */
  #currentPostWasScrolled({ element, ...event }) {
    if (element !== this.#currentPostElement) {
      return;
    }

    this.#currentPostScrolled(event);
  }

  /**
   * Finds the post that contains the eyeline position and updates the current post
   * Also calculates the percentage scrolled within that post
   *
   * @private
   * @param {number} eyeLineOffset - The vertical position of the eyeline
   * @returns {void}
   */
  #findPostMatchingEyeline(eyeLineOffset) {
    let target, percentScrolled;

    // Get target elements from posts currently visible on screen
    let targetElements = Object.values(this.#postsOnScreen).map(
      (post) => post.element
    );

    // If no posts are visible on screen, fall back to all observed post elements
    if (!targetElements.length) {
      targetElements = this.#observedPostElements;
    }

    for (const element of targetElements) {
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

  /**
   * Creates a new IntersectionObserver with the specified callback and options
   *
   * @private
   * @param {Function} callback - The function to call when intersection changes
   * @param {Object} options - Observer configuration options
   * @param {string} options.rootMargin - Margin around the root element
   * @param {Array<number>} options.threshold - Intersection thresholds
   * @returns {IntersectionObserver} The initialized observer
   */
  #initializeObserver(callback, { rootMargin, threshold }) {
    return new IntersectionObserver(
      (entries) => {
        entries.forEach(callback);
      },
      // Explicitly specifying the root as `document` is important.
      // Otherwise, the root margin won't be respected correctly
      { threshold, rootMargin, root: document }
    );
  }

  /**
   * Resets and reinitializes the viewport observers
   * Creates two observers:
   * 1. cloakingObserver - tracks which posts should be cloaked/uncloaked
   * 2. viewportObserver - tracks which posts are visible in the viewport
   * @private
   * @returns {void}
   */
  #resetViewportObservers() {
    this.#cloakingObserver?.disconnect();
    this.#viewportObserver?.disconnect();

    const headerMargin = this.#headerOffset * -1;

    this.#cloakingObserver = this.#initializeObserver(this.trackCloakedPosts, {
      rootMargin: `${this.#cloakOffset}px 0px`,
      // Adding UNCLOAKING_HYSTERESIS_RATIO provides a threshold between completely cloaked (0) and fully visible (1)
      // states. Without this threshold, the intersection observer would only trigger when the element entered or exited
      // the cloaking viewport. The values are clamped between 0 and 1.
      threshold: Array.from(new Set([0, UNCLOAKING_HYSTERESIS_RATIO, 1]))
        .map((n) => Math.max(0, Math.min(n, 1)))
        .sort(),
    });
    this.#viewportObserver = this.#initializeObserver(this.trackVisiblePosts, {
      rootMargin: `${headerMargin}px 0px 0px 0px`,
      threshold: [0, 1],
    });

    for (const element of this.#observedPostElements) {
      this.#cloakingObserver.observe(element);
      this.#viewportObserver.observe(element);
    }
  }

  /**
   * Sets up or removes event listeners for scroll and resize events
   * Also handles page show events for back-forward cache
   *
   * @private
   * @param {boolean} [addListeners=true] - Whether to add (true) or remove (false) listeners
   * @returns {void}
   */
  #setupEventListeners(addListeners = true) {
    if (!addListeners) {
      window.removeEventListener("resize", this.onWindowResize);
      window.removeEventListener("scroll", this.onScroll);

      window.onpageshow = null;

      return;
    }

    const opts = {
      passive: true,
    };

    window.addEventListener("resize", this.onWindowResize, opts);
    window.addEventListener("scroll", this.onScroll, opts);

    // restore scroll position on browsers with aggressive BFCaches (like Safari)
    window.onpageshow = function (event) {
      if (event.persisted) {
        DiscourseURL.routeTo(this.location.pathname);
      }
    };
  }

  /**
   * Creates or removes the debug element that visualizes the eyeline position
   * Only active when DEBUG_EYELINE is true
   *
   * @private
   * @param {boolean} [addElement=true] - Whether to add (true) or remove (false) the debug element
   * @returns {void}
   */
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

  /**
   * Handles scroll events by calculating the new eyeline position and finding the post that matches that position.
   * The eyeline position determines which post is considered current based on the scroll position.
   *
   * When called, this method:
   * 1. Calculates the current eyeline position in the viewport
   * 2. Updates post tracking to find the current visible post at that position
   * 3. Updates the debug visual element if DEBUG_EYELINE is enabled
   *
   * @private
   * @param {boolean} [immediate=false] - If true, processes the eyeline updates synchronously instead of debounced
   * @returns {void}
   */
  #scrollTriggered(immediate = false) {
    const eyelineOffset = this.#calculateEyelineViewportOffset();

    if (immediate) {
      this.#findPostMatchingEyeline(eyelineOffset);
    } else {
      this.#scheduledTimers.set(
        this.#findPostMatchingEyeline,
        discourseDebounce(
          this,
          this.#findPostMatchingEyeline,
          eyelineOffset,
          SCROLL_BATCH_INTERVAL_MS
        )
      );
    }

    if (DEBUG_EYELINE) {
      this.#updateEyelineDebugElementPosition(eyelineOffset);
    }
  }

  /**
   * Updates the cloaking boundaries based on which posts are currently uncloaked
   * Finds the minimum and maximum post numbers that should remain uncloaked
   * and notifies the parent component
   * @private
   * @returns {void}
   */
  #updateCloakBoundaries() {
    const uncloakedPostNumbers = Array.from(this.#uncloakedPostNumbers);

    let above = uncloakedPostNumbers[0] || 0;
    let below = above;

    for (let i = 1; i < uncloakedPostNumbers.length; i++) {
      const postNumber = uncloakedPostNumbers[i];
      above = Math.min(postNumber, above);
      below = Math.max(postNumber, below);
    }

    this.#setCloakingBoundaries(above, below);
  }

  /**
   * Updates the cloak offset based on the current viewport height
   * The cloak offset determines how far beyond the viewport posts remain uncloaked
   *
   * @private
   * @returns {boolean} Whether the offset was changed
   */
  #updateCloakOffset() {
    const newOffset = Math.ceil(this.#viewportHeight * SLACK_FACTOR);

    if (newOffset === this.#cloakOffset) {
      return false;
    }

    this.#cloakOffset = newOffset;
    return true;
  }

  /**
   * Updates the current post element reference and notifies the parent component
   * if the post model has changed
   *
   * @private
   * @param {HTMLElement} newElement - The new post element to set as current
   * @returns {void}
   */
  #updateCurrentPost(newElement) {
    if (this.#currentPostElement === newElement) {
      return;
    }

    const currentPost =
      this.#currentPostElement && elementsToPost.get(this.#currentPostElement);
    const newPost = newElement && elementsToPost.get(newElement);

    this.#currentPostElement = newElement;

    if (currentPost !== newPost) {
      this.#currentPostWasChanged({ post: newPost });
    }
  }

  /**
   * Updates the screen tracking service with the list of posts currently on screen
   * Separates posts into all visible posts and read posts
   * @private
   * @returns {void}
   */
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

  /**
   * Handles window resize events by updating the cloak offset
   * and resetting the viewport observers if needed
   * @private
   * @returns {void}
   */
  #windowResizeTriggered() {
    if (this.#updateCloakOffset()) {
      this.#resetViewportObservers();
    }
  }

  /**
   * Updates the position of the eyeline debug element
   * Only used when DEBUG_EYELINE is true
   *
   * @private
   * @param {number} viewportOffset - The vertical position for the eyeline
   * @returns {void}
   */
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
