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
 * Additionally, an @enabled boolean can be passed to allow for cases where
 * the element is visible in the viewport but you don't want to allow the `loadMore`
 * behaviour. A use case for this is when our controllers return some `canLoadMore`
 * boolean. There is no use attempting to load more from the server in this case,
 * there will be nothing else.
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
  root = this.args.root || null;
  rootMargin = this.args.rootMargin || "0px 0px 0px 0px";
  threshold = this.args.threshold || 0.0;
  enabled = this.args.enabled ?? true;

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
          }}
          class="load-more-sentinel"
          aria-hidden="true"
        />
      </Wrapper>
    {{/let}}
  </template>
}
