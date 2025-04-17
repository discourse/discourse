import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import element from "discourse/helpers/element";
import discourseDebounce from "discourse/lib/debounce";

export default class LoadMore extends Component {
  observer;
  loadMoreAction = this.args.action;
  selector = this.args.selector;
  root = this.args.root || null;
  rootMargin = this.args.rootMargin || "100px";
  threshold = this.args.threshold || 0.1;

  willDestroy() {
    super.willDestroy();
    if (this.observer) {
      this.observer.disconnect();
      this.observer = null;
    }
  }

  @action
  setupObserver(sentinelElement) {
    const rootElement = this.root ? document.querySelector(this.root) : null;

    this.observer = new IntersectionObserver(
      (entries) => {
        // only trigger further action if the expected items matching the selector are present
        if (!this.observer || !document.querySelector(this.selector)) {
          return;
        }

        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            discourseDebounce(this, this.loadMoreAction, 100);
          }
        });
      },
      {
        root: rootElement,
        rootMargin: this.rootMargin,
        threshold: this.threshold,
      }
    );
    this.observer.observe(sentinelElement);
  }

  <template>
    {{#let (element (if (has-block) "div" "")) as |Wrapper|}}
      <Wrapper>
        {{yield}}
        <div
          {{didInsert this.setupObserver}}
          class="load-more-sentinel"
          aria-hidden="true"
          style="height: 1px; width: 100%; margin: 0; padding: 0; pointer-events: none; user-select: none; visibility: hidden; position: relative;"
        />
      </Wrapper>
    {{/let}}
  </template>
}
