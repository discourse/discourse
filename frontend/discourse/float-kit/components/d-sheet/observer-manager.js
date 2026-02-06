/**
 * Observer management module for the d-sheet component system.
 * Provides centralized lifecycle management for IntersectionObserver, ResizeObserver,
 * and wheel event listeners. Handles swipe-out detection through intersection tracking
 * when content scrolls beyond viewport bounds, responsive layout updates through resize
 * observation, and differentiation between touch/wheel interactions for appropriate
 * close behavior. Works in coordination with the sheet controller to manage observer
 * setup, teardown, and state transitions based on detent configurations.
 */
import discourseLater from "discourse/lib/later";

/**
 * Centralized observer management for d-sheet.
 * Handles IntersectionObserver, ResizeObserver, and wheel listener lifecycle.
 */
export default class ObserverManager {
  /**
   * @type {import("./controller").default}
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
   * @type {(() => void)|null}
   */
  #wheelListener = null;

  /**
   * @type {boolean}
   */
  #wheelInteractionDetected = false;

  /**
   * @type {(() => void)|null}
   */
  #wheelCleanup = null;

  /**
   * @param {import("./controller").default} controller - The sheet controller instance
   */
  constructor(controller) {
    this.#controller = controller;
  }

  /**
   * Set up the intersection observer for swipe-out detection.
   *
   * @returns {void}
   */
  setupIntersectionObserver() {
    const { view, content } = this.#controller;

    if (!view || !content) {
      return;
    }

    if (this.#controller.swipeOutDisabledWithDetent) {
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
   * @param {IntersectionObserverEntry[]} entries
   * @returns {void}
   */
  #handleIntersection(entries) {
    for (const entry of entries) {
      if (!entry.isIntersecting && this.#controller.state.openness.isOpen) {
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
   *
   * @returns {void}
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
   *
   * @returns {void}
   */
  #triggerSwipeOut() {
    this.#controller.domAttributes?.disableScrollSnap();
    this.#controller.state.skip.enableClosing();
    this.#controller.handleStateTransition("SWIPED_OUT");
  }

  /**
   * Clean up the intersection observer and wheel listener.
   *
   * @returns {void}
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
   * @param {() => void} onResize - Callback to invoke on resize
   * @returns {void}
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
   *
   * @returns {void}
   */
  cleanup() {
    this.cleanupIntersectionObserver();

    if (this.#resizeObserver) {
      this.#resizeObserver.disconnect();
      this.#resizeObserver = null;
    }
  }
}
