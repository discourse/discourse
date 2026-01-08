import discourseLater from "discourse/lib/later";

/**
 * Centralized observer management for d-sheet.
 * Handles IntersectionObserver, ResizeObserver, and wheel listener lifecycle.
 */
export default class ObserverManager {
  /**
   * @type {Object}
   */
  #controller;

  /**
   * @type {IntersectionObserver|null}
   */
  #intersectionObserver = null;

  /**
   * @type {ResizeObserver|null}
   */
  #resizeObserver = null;

  /**
   * @type {Function|null}
   */
  #wheelListener = null;

  /**
   * @type {boolean}
   */
  #wheelInteractionDetected = false;

  /**
   * @type {Function|null}
   */
  #wheelCleanup = null;

  /**
   * @param {Object} controller - The sheet controller instance
   */
  constructor(controller) {
    this.#controller = controller;
  }

  /**
   * Update observers based on current state.
   * Call this when currentState or swipeOutDisabled changes.
   */
  updateObservers() {
    const shouldHaveIntersection =
      this.#controller.currentState === "open" &&
      !this.#controller.swipeOutDisabled;

    if (shouldHaveIntersection && !this.#intersectionObserver) {
      this.setupIntersectionObserver();
    } else if (!shouldHaveIntersection && this.#intersectionObserver) {
      this.cleanupIntersectionObserver();
    }
  }

  /**
   * Set up the intersection observer for swipe-out detection.
   */
  setupIntersectionObserver() {
    const { view, content } = this.#controller;

    if (!view || !content) {
      return;
    }

    if (this.#controller.swipeOutDisabled) {
      this.cleanupIntersectionObserver();
      return;
    }

    this.cleanupIntersectionObserver();

    this.#wheelInteractionDetected = false;
    this.#wheelListener = () => {
      this.#wheelInteractionDetected = true;
    };
    window.addEventListener("wheel", this.#wheelListener, {
      passive: true,
      once: true,
    });

    this.#intersectionObserver = new IntersectionObserver(
      (entries) => this.#handleIntersection(entries),
      {
        root: view,
        threshold: [0],
      }
    );

    this.#intersectionObserver.observe(content);
  }

  /**
   * Handle intersection observer entries.
   *
   * @param {Array<IntersectionObserverEntry>} entries
   */
  #handleIntersection(entries) {
    for (const entry of entries) {
      if (!entry.isIntersecting && this.#controller.currentState === "open") {
        this.#controller.viewHiddenByObserver = true;
        this.#controller.domAttributes?.hideForSwipeOut();

        requestAnimationFrame(() => {
          if (this.#wheelInteractionDetected) {
            this.#handleWheelSwipeOut();
          } else {
            this.#triggerSwipeOut();
          }
        });
      }
    }
  }

  /**
   * Handle swipe-out when wheel interaction was detected.
   */
  #handleWheelSwipeOut() {
    let lastDeltaY = 100000;

    const blockWheel = (e) => {
      const currentDeltaY = Math.abs(e.deltaY);
      if (lastDeltaY < currentDeltaY) {
        window.removeEventListener("wheel", blockWheel, { passive: false });
      } else {
        e.preventDefault();
      }
      lastDeltaY = currentDeltaY;
    };

    window.addEventListener("wheel", blockWheel, { passive: false });
    this.#wheelCleanup = () =>
      window.removeEventListener("wheel", blockWheel, { passive: false });

    discourseLater(() => {
      this.#wheelCleanup?.();
      this.#wheelCleanup = null;
      this.#triggerSwipeOut();
    }, 100);
  }

  /**
   * Trigger the swipe-out transition.
   */
  #triggerSwipeOut() {
    this.#controller.domAttributes?.disableScrollSnap();
    this.#controller.closingWithoutAnimation = true;
    this.#controller.handleStateTransition("SWIPED_OUT");
  }

  /**
   * Clean up the intersection observer and wheel listener.
   */
  cleanupIntersectionObserver() {
    if (this.#intersectionObserver) {
      this.#intersectionObserver.disconnect();
      this.#intersectionObserver = null;
    }

    if (this.#wheelListener) {
      window.removeEventListener("wheel", this.#wheelListener);
      this.#wheelListener = null;
    }

    if (this.#wheelCleanup) {
      this.#wheelCleanup();
      this.#wheelCleanup = null;
    }
  }

  /**
   * Set up the resize observer for view and content elements.
   *
   * @param {Function} onResize - Callback to invoke on resize
   */
  setupResizeObserver(onResize) {
    if (this.#resizeObserver) {
      this.#resizeObserver.disconnect();
    }

    const { view, content } = this.#controller;

    let viewFirstObservation = true;
    let contentFirstObservation = true;

    this.#resizeObserver = new ResizeObserver((entries) => {
      for (const entry of entries) {
        if (entry.target === view) {
          if (viewFirstObservation) {
            viewFirstObservation = false;
            continue;
          }
          onResize();
        } else if (entry.target === content) {
          if (contentFirstObservation) {
            this.#controller.calculateDimensionsIfReady();
            contentFirstObservation = false;
            continue;
          }
          onResize();
        }
      }
    });

    if (view) {
      this.#resizeObserver.observe(view, { box: "border-box" });
    }
    if (content) {
      this.#resizeObserver.observe(content, { box: "border-box" });
    }
  }

  /**
   * Clean up all observers.
   */
  cleanup() {
    this.cleanupIntersectionObserver();

    if (this.#resizeObserver) {
      this.#resizeObserver.disconnect();
      this.#resizeObserver = null;
    }
  }
}
