import Component from "@glimmer/component";
import { action } from "@ember/object";
import element from "discourse/helpers/element";
import discourseDebounce from "discourse/lib/debounce";
import observeIntersection from "discourse/modifiers/observe-intersection";

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
 * @param {Function} action - The action to trigger when more content should be loaded
 * @param {boolean} [enabled=true] - Whether to allow the loadMore action to trigger.
 *   Use this when you know there's no more content available (e.g., `model.canLoadMore`).
 *   When false, the observer continues to run but the action won't be triggered.
 * @param {boolean} [isLoading=false] - Whether content is currently loading.
 *   When true, the IntersectionObserver won't be created, preventing premature triggers
 *   during initial content load. Pass this to avoid race conditions during page initialization.
 * @param {string} [rootMargin="0px 0px 0px 0px"] - Margin around the root element for intersection detection
 * @param {number} [threshold=0.0] - Threshold at which the intersection callback is triggered
 * @param {string} [root=null] - CSS selector for the root element to observe intersection within
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
 * @example With enabled and isLoading to prevent premature loading:
 * ```gjs
 * <LoadMore
 *   @action={{this.loadMoreUsers}}
 *   @enabled={{this.model.canLoadMore}}
 *   @isLoading={{this.isLoading}}
 * >
 *   <UserList @users={{this.model}} />
 * </LoadMore>
 * ```
 *
 * @example With custom IntersectionObserver options:
 * ```gjs
 * <LoadMore
 *   @action={{this.fetchMoreUsers}}
 *   @rootMargin="100px"
 *   @threshold={{0.2}}
 *   @root={{this.scrollContainer}}
 *   class="users-container"
 * />
 * ```
 */
export default class LoadMore extends Component {
  observer;
  root = this.args.root || null;
  rootMargin = this.args.rootMargin || "0px 0px 0px 0px";
  threshold = this.args.threshold || 0.0;

  get enabled() {
    return this.args.enabled ?? true;
  }

  @action
  onIntersection(entry) {
    if (ENABLE_LOAD_MORE_OBSERVER && entry.isIntersecting && this.enabled) {
      discourseDebounce(this, this.args.action, 100);
    }
  }

  <template>
    {{#let (element (if (has-block) "div" "")) as |Wrapper|}}
      <Wrapper ...attributes>
        {{yield}}
        <div
          {{observeIntersection
            this.onIntersection
            threshold=this.threshold
            rootMargin=this.rootMargin
            root=this.root
            isLoading=@isLoading
          }}
          class="load-more-sentinel"
          aria-hidden="true"
        />
      </Wrapper>
    {{/let}}
  </template>
}
