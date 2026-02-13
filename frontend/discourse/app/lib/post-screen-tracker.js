import discourseDebounce from "discourse/lib/debounce";

const DEBOUNCE_MS = 10;

/**
 * PostScreenTracker
 *
 * A lightweight utility for tracking which post elements are visible in the
 * viewport and feeding that information to the screen-track service.
 *
 * This is the reusable core of the screen-tracking pipeline:
 *   1. An IntersectionObserver detects which posts are on screen.
 *   2. Visible post numbers (and which of those are already read) are
 *      forwarded to screenTrack.setOnscreen() on a debounced cadence.
 *
 * Usage:
 *   const tracker = new PostScreenTracker(screenTrackService);
 *   // For each post element:
 *   tracker.observe(element, postModel);
 *   // When element is torn down:
 *   tracker.unobserve(element);
 *   // When done:
 *   tracker.destroy();
 */
export default class PostScreenTracker {
  #screenTrack;
  #observer;
  #elementToPost = new WeakMap();
  #postsOnScreen = {};

  #handleEntry = (entry) => {
    const post = this.#elementToPost.get(entry.target);
    if (!post) {
      return;
    }

    if (entry.isIntersecting) {
      this.#postsOnScreen[post.post_number] = post;
    } else {
      delete this.#postsOnScreen[post.post_number];
    }

    discourseDebounce(this, this.#updateScreenTracking, DEBOUNCE_MS);
  };

  #updateScreenTracking = () => {
    const onScreen = [];
    const readOnScreen = [];

    for (const post of Object.values(this.#postsOnScreen)) {
      onScreen.push(post.post_number);
      if (post.read) {
        readOnScreen.push(post.post_number);
      }
    }

    this.#screenTrack.setOnscreen(onScreen, readOnScreen);
  };

  constructor(screenTrack, { headerOffset = 0 } = {}) {
    this.#screenTrack = screenTrack;

    const headerMargin = headerOffset * -1;
    this.#observer = new IntersectionObserver(
      (entries) => entries.forEach(this.#handleEntry),
      {
        rootMargin: `${headerMargin}px 0px 0px 0px`,
        threshold: [0, 1],
      }
    );
  }

  observe(element, post) {
    this.#elementToPost.set(element, post);
    this.#observer.observe(element);
  }

  unobserve(element) {
    const post = this.#elementToPost.get(element);
    if (post) {
      delete this.#postsOnScreen[post.post_number];
    }
    this.#elementToPost.delete(element);
    this.#observer.unobserve(element);
  }

  destroy() {
    this.#observer.disconnect();
    this.#elementToPost = new WeakMap();
    this.#postsOnScreen = {};
  }
}
