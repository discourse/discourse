// @ts-check
import Component from "@glimmer/component";
import { DEBUG } from "@glimmer/env";
import { cached } from "@glimmer/tracking";
import { assert } from "@ember/debug";
import { action } from "@ember/object";
import discourseDebounce from "discourse/lib/debounce";
/** @type {import("discourse/ui-kit/helpers/d-element.gjs").default} */
import dElement from "discourse/ui-kit/helpers/d-element";
import dObserveIntersection from "discourse/ui-kit/modifiers/d-observe-intersection";

let ENABLE_LOAD_MORE_OBSERVER = true;

// Exported functions to control the behavior in tests.
export function disableLoadMoreObserver() {
  ENABLE_LOAD_MORE_OBSERVER = false;
}

export function enableLoadMoreObserver() {
  ENABLE_LOAD_MORE_OBSERVER = true;
}

/**
 * Infinite-scroll trigger backed by `IntersectionObserver`. Renders a hidden
 * sentinel element after the yielded content; once the sentinel scrolls into
 * view, `@action` is invoked (debounced) so the consumer can fetch the next
 * page.
 *
 * Use the block form to wrap the existing list and have the sentinel
 * naturally attach to its bottom edge. Use the no-block form to drop a
 * standalone sentinel anywhere on the page when the wrapper is undesirable.
 *
 * `@enabled` and `@isLoading` exist to prevent unwanted triggers:
 *
 * - `@enabled={{false}}` keeps the observer running but blocks the action,
 *   useful when you've reached the end of the data.
 * - `@isLoading={{true}}` skips creating the observer entirely, avoiding
 *   race conditions on initial load.
 *
 * The remaining args (`@rootMargin`, `@threshold`, `@root`) map 1:1 to
 * `IntersectionObserver` options.
 *
 * @example
 * <DLoadMore @action={{this.loadMoreTopics}}>
 *   <TopicList @topics={{this.topics}} />
 * </DLoadMore>
 *
 * @example
 * <DLoadMore
 *   @action={{this.loadMoreUsers}}
 *   @enabled={{this.model.canLoadMore}}
 *   @isLoading={{this.isLoading}}
 * />
 */

/**
 * @typedef DLoadMoreSignature
 *
 * @property {object} Args
 *
 * @property {Function} Args.action Required. Invoked (debounced) when the sentinel becomes visible. The component does not pass arguments — the consumer typically captures the next-page state in its own closure.
 * @property {boolean} [Args.enabled] When false, the action is suppressed even though the observer keeps running. Defaults to `true`. Use `model.canLoadMore` or similar.
 * @property {boolean} [Args.isLoading] When true, no `IntersectionObserver` is created at all. Defaults to `false`. Use to suppress trigger races during page initialization.
 * @property {string} [Args.rootMargin] CSS-style margin around the root element for intersection detection. Defaults to `"0px 0px 0px 0px"`.
 * @property {number} [Args.threshold] Visibility fraction at which the callback fires. Defaults to `0.0` (any pixel visible).
 * @property {Element|null} [Args.root] Element to observe within. `null` (the default) means the viewport.
 *
 * @property {HTMLDivElement} Element The wrapper `<div>` rendered when a block is yielded. When no block is given, the component renders only the sentinel and `...attributes` has no element to attach to.
 *
 * @property {object} Blocks
 * @property {[]} Blocks.default Optional content the sentinel should be appended after. When given, the wrapper `<div>` is rendered around both block and sentinel.
 */

/** @extends {Component<DLoadMoreSignature>} */
export default class DLoadMore extends Component {
  observer;
  root = this.args.root || null;
  rootMargin = this.args.rootMargin || "0px 0px 0px 0px";
  threshold = this.args.threshold || 0.0;

  @cached
  get validateArgs() {
    if (DEBUG) {
      assert(
        "[d-load-more] @action is required",
        typeof this.args.action === "function"
      );
    }
    return null;
  }

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
    {{this.validateArgs}}
    {{#let (dElement (if (has-block) "div" "")) as |Wrapper|}}
      <Wrapper ...attributes>
        {{yield}}
        <div
          {{dObserveIntersection
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
