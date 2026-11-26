import Component from "@glimmer/component";
import { action } from "@ember/object";
import discourseDebounce from "discourse/lib/debounce";
import dObserveIntersection from "discourse/ui-kit/modifiers/d-observe-intersection";

let ENABLE_LOAD_MORE_OBSERVER = true;

// Exported functions to control the behavior in tests
export function disableLoadMoreObserver() {
  ENABLE_LOAD_MORE_OBSERVER = false;
}

export function enableLoadMoreObserver() {
  ENABLE_LOAD_MORE_OBSERVER = true;
}

interface DLoadMoreSignature {
  Element: HTMLDivElement;

  Args: {
    /** The action to trigger when more content should be loaded. */
    action: () => void;

    /**
     * Whether to allow the loadMore action to trigger. Defaults to `true`.
     * Use this when you know there's no more content available (e.g., `model.canLoadMore`).
     * When false, the observer continues to run but the action won't be triggered.
     */
    enabled?: boolean;

    /**
     * Whether content is currently loading. Defaults to `false`.
     * When true, the IntersectionObserver won't be created, preventing premature triggers
     * during initial content load. Pass this to avoid race conditions during page initialization.
     */
    isLoading?: boolean;

    /** Margin around the root element for intersection detection. Defaults to `"0px 0px 0px 0px"`. */
    rootMargin?: string;

    /** Threshold at which the intersection callback is triggered. Defaults to `0.0`. */
    threshold?: number;

    /**
     * The element to observe intersection within, or a CSS selector for it. Defaults to `null`.
     * Pass the element itself when it mounts in the same render as the
     * sentinel, since a selector cannot resolve a root that does not exist yet.
     */
    root?: string | Element | null;
  };

  Blocks: {
    /** Content rendered above the sentinel. */
    default: [];
  };
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
 * @example With custom IntersectionObserver options (attributes land on the
 * sentinel itself when no block is given, so consumers can style it):
 * ```gjs
 * <LoadMore
 *   @action={{this.fetchMoreUsers}}
 *   @rootMargin="100px"
 *   @threshold={{0.2}}
 *   @root={{this.scrollContainer}}
 *   class="users-list__sentinel"
 * />
 * ```
 */
export default class DLoadMore extends Component<DLoadMoreSignature> {
  observer: IntersectionObserver | undefined;

  // Getters, not fields: a field snapshots the argument at construction, so an `@root` that
  // is captured after this component mounts (its container and the sentinel rendering in the
  // same pass) would never reach the observer, silently leaving it rooted at the wrong node.
  get root() {
    return this.args.root || null;
  }

  get rootMargin() {
    return this.args.rootMargin || "0px 0px 0px 0px";
  }

  get threshold() {
    return this.args.threshold || 0.0;
  }

  get enabled() {
    return this.args.enabled ?? true;
  }

  @action
  onIntersection(entry: IntersectionObserverEntry) {
    if (ENABLE_LOAD_MORE_OBSERVER && entry.isIntersecting && this.enabled) {
      discourseDebounce(this, this.args.action, 100);
    }
  }

  <template>
    {{#if (has-block)}}
      <div ...attributes>
        {{yield}}
        <div
          aria-hidden="true"
          class="load-more-sentinel"
          {{dObserveIntersection
            this.onIntersection
            threshold=this.threshold
            rootMargin=this.rootMargin
            root=this.root
            isLoading=@isLoading
          }}
        />
      </div>
    {{else}}
      <div
        aria-hidden="true"
        class="load-more-sentinel"
        ...attributes
        {{dObserveIntersection
          this.onIntersection
          threshold=this.threshold
          rootMargin=this.rootMargin
          root=this.root
          isLoading=@isLoading
        }}
      />
    {{/if}}
  </template>
}
