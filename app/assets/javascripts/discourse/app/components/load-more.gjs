import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import element from "discourse/helpers/element";
import discourseDebounce from "discourse/lib/debounce";

let ENABLE_LOAD_MORE_OBSERVER = true;

// Exported functions to control the behavior in tests
export function disableLoadMoreObserver() {
  ENABLE_LOAD_MORE_OBSERVER = false;
}

export function enableLoadMoreObserver() {
  ENABLE_LOAD_MORE_OBSERVER = true;
}

/**
 * A component that implements infinite loading using IntersectionObserver.
 *
 * LoadMore triggers an action when a sentinel element becomes visible in the viewport,
 * which is typically used to load additional content. Besides the `action` argument, it also takes
 * in additional options to customize the observer's behavior;
 * Refer to https://developer.mozilla.org/en-US/docs/Web/API/IntersectionObserver/IntersectionObserver#options for a full list.
 *
 * @example Basic usage with a block:
 * ```gjs
 * <LoadMore @action={{this.loadMoreTopics}}>
 *   <TopicList @topics={{this.topics}} />
 * </LoadMore>
 * ```
 *
 * @example Usage without a block (as standalone sentinel):
 * ```gjs
 * <div class="my-content">
 *   {{#each this.items as |item|}}
 *     <ItemComponent @item={{item}} />
 *   {{/each}}
 * </div>
 *
 * <LoadMore @action={{this.loadMore}} />
 * ```
 *
 * @example With custom options:
 * ```gjs
 * <LoadMore
 *   @action={{this.fetchMoreUsers}}
 *   @rootMargin="100px"
 *   @threshold={{0.2}}
 *   @root={{this.root}}
 *   class="users-container"
 * />
 * ```
 */
export default class LoadMore extends Component {
  observer;
  loadMoreAction = this.args.action;
  root = this.args.root || null;
  rootMargin = this.args.rootMargin || "0px 0px 0px 0px";
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
    if (!ENABLE_LOAD_MORE_OBSERVER) {
      return;
    }

    const rootElement = this.root ? document.querySelector(this.root) : null;

    this.observer = new IntersectionObserver(
      (entries) => {
        if (!this.observer) {
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
      <Wrapper ...attributes>
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
