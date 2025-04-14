import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { scheduleOnce } from "@ember/runloop";

export default class LoadMore extends Component {
  observer;
  loadMoreAction;
  selector;
  root;
  rootMargin;
  threshold;
  currentObservedElement;
  isLoading = false;

  constructor(owner, args) {
    super(owner, args);
    this.loadMoreAction = args.action;
    this.selector = args.selector;
    this.root = args.root || null;
    this.rootMargin = args.rootMargin || "100px";
    this.threshold = args.threshold || 1.0;
  }

  willDestroy() {
    super.willDestroy();
    if (this.observer) {
      this.observer.disconnect();
      this.observer = null;
    }
  }

  @action
  setupObserver() {
    const rootElement = this.root ? document.querySelector(this.root) : null;

    this.observer = new IntersectionObserver(
      (entries) => {
        if (!this.observer) {
          return;
        }

        entries.forEach((entry) => {
          const bcr = entry.boundingClientRect;
          const isBottomVisible =
            bcr.bottom > 0 && bcr.bottom < window.innerHeight;

          if (isBottomVisible && !this.isLoading) {
            // Prevent multiple simultaneous calls
            this.isLoading = true;

            // Disconnect observer until we find the new last element
            if (this.currentObservedElement) {
              this.observer.unobserve(this.currentObservedElement);
            }

            // Call the action
            this.loadMoreAction();

            // After render is complete, find new elements and reset state
            scheduleOnce("afterRender", this, this.observeLoadedLastElement);
          }
        });
      },
      {
        root: rootElement,
        rootMargin: this.rootMargin,
        threshold: this.threshold,
      }
    );

    this.findAndObserveLastElement();
  }

  findAndObserveLastElement() {
    const allElements = document.querySelectorAll(this.selector);

    if (allElements.length > 0) {
      this.currentObservedElement = allElements[allElements.length - 1];
      this.observer.observe(this.currentObservedElement);
    }
  }

  observeLoadedLastElement() {
    this.findAndObserveLastElement();
    this.isLoading = false;
  }

  <template>
    <div {{didInsert this.setupObserver}} ...attributes>
      {{yield}}
    </div>
  </template>
}
