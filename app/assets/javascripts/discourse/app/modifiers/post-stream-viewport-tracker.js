import { cancel, schedule } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import discourseDebounce from "discourse/lib/debounce";
import { bind } from "discourse/lib/decorators";
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

// Set to true to visualize the eyeline position with a red line
const DEBUG_EYELINE = false;

// Global flag to enable/disable the cloaking mechanism
let cloakingEnabled = true;

/**
 * Globally disables the cloaking mechanism for all posts
 *
 * USE ONLY FOR TESTING PURPOSES.
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
 * Maps elements in the post stream to their corresponding post.
 * Uses WeakMap to avoid memory leaks when elements are removed.
 *
 * @type {WeakMap<HTMLElement, Object>}
 */
const elementsToPost = new WeakMap();

export default class PostStreamViewportTracker {
  /**
   * Reference to the bottom boundary element used for eyeline calculations
   * @type {HTMLElement}
   */
  #bottomBoundaryElement;

  /**
   * Distance beyond viewport to keep posts uncloaked (calculated from viewport height)
   * @type {number}
   */
  #cloakOffset;

  /**
   * Map of post IDs to their heights when cloaked
   * Used to maintain correct scroll position when posts are cloaked
   * @type {Object<number, number>}
   */
  #cloakedPostsHeight = {};

  /**
   * IntersectionObserver that tracks which posts should be cloaked/uncloaked
   * @type {IntersectionObserver}
   */
  #cloakingObserver;

  /**
   * Callback function to notify when the current post changes
   * @type {Function}
   */
  #currentPostChanged;

  /**
   * Reference to the DOM element of the current post being viewed
   * @type {HTMLElement}
   */
  #currentPostElement;

  /**
   * Callback function to notify when the scroll position within the current post changes
   * @type {Function}
   */
  #currentPostScrolled;

  /**
   * Debug element used to visualize the eyeline position
   * @type {HTMLElement}
   */
  #eyelineDebugElement;

  /**
   * Offset from the top of the viewport for the site header
   * Used in calculations to determine visible posts
   * @type {number}
   */
  #headerOffset;

  /**
   * Set of posts' DOM nodes being observed by the intersection observers
   * @type {Set<HTMLElement>}
   */
  #observedPostElements = new Set();

  /**
   * Map of post numbers to their post models and DOM elements that are currently on screen
   * Used to track which posts are visible in the viewport for eyeline calculations and screen tracking
   * @type {Object<number, {post: Object, element: HTMLElement}>}
   */
  #postsOnScreen = {};

  /**
   * Map to store scheduled/debounced timers for various tracker functions
   * Used to track and cancel pending timers when the component is destroyed
   * @type {Map<Function, number>}
   */
  #scheduledTimers = new Map();

  /**
   * Reference to the screen track service for tracking post visibility
   * @type {Object}
   */
  #screenTrackService;

  /**
   * Callback function to update the cloaking boundaries in the parent component
   * @type {Function}
   */
  #setCloakingBoundaries;

  /**
   * Set of post numbers that are currently uncloaked (visible or near viewport)
   * @type {Set<number>}
   */
  #uncloakedPostNumbers = new Set();

  /**
   * IntersectionObserver that tracks which posts are visible in the viewport
   * @type {IntersectionObserver}
   */
  #viewportObserver;

  /**
   * Reference to the wrapper element containing all posts
   * @type {HTMLElement}
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
   * @param {Array} [post] - The post model associated with the element
   * @returns {Function} Cleanup function that removes observers when the element is destroyed
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
   * @param {Object} options.trackedArgs - Additional tracked arguments that trigger cleanup when changed
   * @returns {Function} Cleanup function that removes observers, event listeners and clears state
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
        // forces updates performed when the scroll is triggered
        this.#scrollTriggered();
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
        this.#cloakedPostsHeight = {};
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
   * @returns {Object<number, {post: Object, element: HTMLElement}>}
   */
  get postsOnScreen() {
    return this.#postsOnScreen;
  }

  /**
   * Returns the modifier for registering the bottom boundary element
   * @returns {Modifier}
   */
  get registerBottomBoundary() {
    return this.#registerBottomBoundary;
  }

  /**
   * Returns the modifier for registering post elements
   * @returns {Modifier}
   */
  get registerPost() {
    return this.#registerPost;
  }

  /**
   * Returns the main setup modifier
   * @returns {Modifier}
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
    if (!cloakingEnabled || !post || cloakingPrevented.posts.has(post.id)) {
      return { active: false };
    }

    const height = this.#cloakedPostsHeight[post.id];

    return height && (post.post_number < above || post.post_number > below)
      ? { active: true, style: htmlSafe("height: " + height + "px;") }
      : { active: false };
  }

  /**
   * Intersection observer callback for tracking which posts should be cloaked
   * Updates the cloaking state based on post visibility
   *
   * @param {IntersectionObserverEntry} entry - The intersection observer entry
   */
  @bind
  trackCloakedPosts(entry) {
    const { target, isIntersecting } = entry;
    const post = elementsToPost.get(target);

    if (!post) {
      return;
    }

    const postNumber = post.post_number;

    if (isIntersecting) {
      // entering the visibility area
      this.#uncloakedPostNumbers.add(postNumber);
      delete this.#cloakedPostsHeight[post.id];
    } else {
      // entering the cloaking area
      this.#uncloakedPostNumbers.delete(postNumber);

      // saves the current post height to prevent jumps while scrolling with existing cloaked posts
      this.#cloakedPostsHeight[post.id] = target.offsetHeight;
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
   * Calculates the position of the "eyeline" - the horizontal line in the viewport
   * that determines which post is considered the current post
   *
   * The eyeline position is dynamically calculated based on scroll position and
   * moves from the top of the viewport (when at the beginning of the topic)
   * to the bottom of the viewport (when at the end of the topic)
   *
   * @returns {number} The vertical offset of the eyeline in viewport coordinates
   */
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

  /**
   * Notifies the parent component that the current post has changed
   *
   * @param {Object} event - Event data containing the new current post
   */
  #currentPostWasChanged(event) {
    this.#currentPostChanged(event);
  }

  /**
   * Notifies the parent component about scroll position changes within the current post
   * Only triggers if the element matches the current post element
   *
   * @param {Object} params - Parameters containing element and scroll data
   * @param {HTMLElement} params.element - The post element
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
   * @param {number} eyeLineOffset - The vertical position of the eyeline
   */
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

  /**
   * Creates a new IntersectionObserver with the specified callback and options
   *
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
   */
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

    for (const element of this.#observedPostElements) {
      this.#cloakingObserver.observe(element);
      this.#viewportObserver.observe(element);
    }
  }

  /**
   * Sets up or removes event listeners for scroll and resize events
   * Also handles page show events for back-forward cache
   *
   * @param {boolean} addListeners - Whether to add (true) or remove (false) listeners
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
   * @param {boolean} addElement - Whether to add (true) or remove (false) the debug element
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
   * Handles scroll events by calculating the new eyeline position
   * and finding the post that matches that position
   * Also updates the debug element if enabled
   */
  #scrollTriggered() {
    const eyelineOffset = this.#calculateEyelineViewportOffset();

    this.#scheduledTimers.set(
      this.#findPostMatchingEyeline,
      discourseDebounce(
        this,
        this.#findPostMatchingEyeline,
        eyelineOffset,
        SCROLL_BATCH_INTERVAL_MS
      )
    );

    if (DEBUG_EYELINE) {
      this.#updateEyelineDebugElementPosition(eyelineOffset);
    }
  }

  /**
   * Updates the cloaking boundaries based on which posts are currently uncloaked
   * Finds the minimum and maximum post numbers that should remain uncloaked
   * and notifies the parent component
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
   * @returns {boolean} Whether the offset was changed
   */
  #updateCloakOffset() {
    const newOffset = Math.ceil(window.innerHeight * SLACK_FACTOR);

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
   * @param {HTMLElement} newElement - The new post element to set as current
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
   * @param {number} viewportOffset - The vertical position for the eyeline
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
