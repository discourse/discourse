import { cancel } from "@ember/runloop";
import discourseLater from "discourse/lib/later";

export default class ObserverManager {
  #controller;
  #intersectionObserver = null;
  #resizeObserver = null;

  #resizeObserverOnResize = null;
  #resizeObservedView = null;
  #resizeObservedContent = null;
  #viewFirstObservation = true;
  #contentFirstObservation = true;
  #wheelListener = null;
  #wheelInteractionDetected = false;
  #wheelCleanup = null;
  #wheelTimer = null;
  #intersectionFrame = null;

  constructor(controller) {
    this.#controller = controller;
  }

  setupIntersectionObserver() {
    const { view, content } = this.#controller;

    if (!view || !content) {
      return;
    }

    if (
      this.#controller.swipeDisabled ||
      this.#controller.swipeOutDisabledWithDetent
    ) {
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

  #handleIntersection(entries) {
    for (const entry of entries) {
      if (!entry.isIntersecting && this.#controller.state.openness.isOpen) {
        this.#controller.domAttributes?.hideForSwipeOut();

        this.#intersectionFrame = requestAnimationFrame(() => {
          this.#intersectionFrame = null;

          if (this.#controller.isDestroying || this.#controller.isDestroyed) {
            return;
          }

          if (this.#wheelInteractionDetected) {
            this.#handleWheelSwipeOut();
          } else {
            this.#triggerSwipeOut();
          }
        });
      }
    }
  }

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

    this.#wheelTimer = discourseLater(() => {
      this.#wheelTimer = null;

      if (this.#controller.isDestroying || this.#controller.isDestroyed) {
        return;
      }

      this.#wheelCleanup?.();
      this.#wheelCleanup = null;
      this.#triggerSwipeOut();
    }, 100);
  }

  #triggerSwipeOut() {
    if (!this.#controller.state.openness.isOpen) {
      return;
    }

    this.#controller.domAttributes?.disableScrollSnap();
    this.#controller.state.skip.enableClosing();
    this.#controller.handleSwipeOut();
  }

  cleanupIntersectionObserver() {
    if (this.#intersectionFrame !== null) {
      cancelAnimationFrame(this.#intersectionFrame);
      this.#intersectionFrame = null;
    }

    if (this.#wheelTimer) {
      cancel(this.#wheelTimer);
      this.#wheelTimer = null;
    }

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

  setupResizeObserver(onResize) {
    this.#resizeObserverOnResize = onResize;

    if (!this.#resizeObserver) {
      this.#resizeObserver = new ResizeObserver((entries) => {
        for (const entry of entries) {
          if (entry.target === this.#resizeObservedView) {
            if (this.#viewFirstObservation) {
              this.#viewFirstObservation = false;
              continue;
            }
            this.#resizeObserverOnResize?.();
          } else if (entry.target === this.#resizeObservedContent) {
            if (this.#contentFirstObservation) {
              this.#contentFirstObservation = false;

              if (this.#controller.dimensions) {
                this.#resizeObserverOnResize?.();
              } else {
                this.#controller.calculateDimensionsIfReady();
              }
              continue;
            }
            this.#resizeObserverOnResize?.();
          }
        }
      });
    }

    this.#observeResizeTargets();
  }

  #observeResizeTargets() {
    const { view, content } = this.#controller;

    if (view && view !== this.#resizeObservedView) {
      if (this.#resizeObservedView) {
        this.#resizeObserver.unobserve(this.#resizeObservedView);
      }
      this.#resizeObservedView = view;
      this.#viewFirstObservation = true;
      this.#resizeObserver.observe(view, { box: "border-box" });
    }

    if (content && content !== this.#resizeObservedContent) {
      if (this.#resizeObservedContent) {
        this.#resizeObserver.unobserve(this.#resizeObservedContent);
      }
      this.#resizeObservedContent = content;
      this.#contentFirstObservation = true;
      this.#resizeObserver.observe(content, { box: "border-box" });
    }
  }

  unobserveResizeTarget(element) {
    if (element === this.#resizeObservedView) {
      this.#resizeObserver?.unobserve(element);
      this.#resizeObservedView = null;
      this.#viewFirstObservation = true;
    }

    if (element === this.#resizeObservedContent) {
      this.#resizeObserver?.unobserve(element);
      this.#resizeObservedContent = null;
      this.#contentFirstObservation = true;
    }
  }

  cleanup() {
    this.cleanupIntersectionObserver();

    if (this.#resizeObserver) {
      this.#resizeObserver.disconnect();
      this.#resizeObserver = null;
    }
    this.#resizeObserverOnResize = null;
    this.#resizeObservedView = null;
    this.#resizeObservedContent = null;
    this.#viewFirstObservation = true;
    this.#contentFirstObservation = true;
  }
}
