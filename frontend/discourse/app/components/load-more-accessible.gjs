import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import LoadMore from "discourse/components/load-more";
import { i18n } from "discourse-i18n";

/**
 * @component LoadMoreAccessible
 *
 * Extends the standard LoadMore component with screen reader accessibility.
 * Provides both intersection observer based loading and manual load buttons
 * for users who navigate via headings or other assistive technologies.
 *
 * @param {Function} @action - Function to call when loading more content
 * @param {"above"|"below"} @direction - Direction of loading (affects button text and aria labels)
 * @param {boolean} @enabled - Whether loading is enabled (default: true)
 * @param {boolean} @canLoadMore - Whether more content is available to load
 * @param {string} @loadingText - Optional custom loading text
 * @param {Array<number>} @existingPostNumbers - Array of existing post numbers from PostStream
 * @param {Object} @firstAvailablePost - First available post from PostStream
 * @param {Object} @lastAvailablePost - Last available post from PostStream
 */
export default class LoadMoreAccessible extends Component {
  @service appEvents;
  @service accessibilityAnnouncer;

  @tracked isLoading = false;
  @tracked pendingFocusContext = null;
  @tracked loadTriggeredByIntersection = false;

  #hasPostsAppendedListener = false;

  willDestroy() {
    super.willDestroy(...arguments);

    // Only remove listeners that were actually added
    if (this.#hasPostsAppendedListener) {
      this.appEvents.off(
        "post-stream:posts-appended",
        this,
        this.#handlePostsAppended
      );
      this.#hasPostsAppendedListener = false;
    }
  }

  get direction() {
    return this.args.direction || "below";
  }

  get isLoadingAbove() {
    return this.direction === "above";
  }

  get canLoadMore() {
    return this.args.canLoadMore ?? true;
  }

  get enabled() {
    return this.args.enabled ?? true;
  }

  #handlePostsAppended() {
    if (!this.pendingFocusContext) {
      return;
    }

    const focusContext = this.pendingFocusContext;

    // Clear the pending context
    this.pendingFocusContext = null;
    if (this.#hasPostsAppendedListener) {
      this.appEvents.off(
        "post-stream:posts-appended",
        this,
        this.#handlePostsAppended
      );
      this.#hasPostsAppendedListener = false;
    }

    // Schedule focus for next render cycle
    schedule("afterRender", () => {
      this.#focusAppropriateNewPost(focusContext);
    });
  }

  get buttonLabel() {
    if (this.args.loadingText) {
      return this.args.loadingText;
    }

    return this.isLoadingAbove
      ? i18n("post.load_more_posts_above")
      : i18n("post.load_more_posts_below");
  }

  @action
  async handleIntersectionLoad() {
    this.loadTriggeredByIntersection = true;
    return this.#loadWithFocusManagement();
  }

  async #loadWithFocusManagement() {
    if (!this.enabled || !this.canLoadMore || this.isLoading) {
      return;
    }

    try {
      this.isLoading = true;

      const existingPostNumbers = this.args.existingPostNumbers;
      const currentFocusContext =
        this.#getCurrentFocusContext(existingPostNumbers);

      await this.args.action();

      if (this.loadTriggeredByIntersection) {
        this.pendingFocusContext = currentFocusContext;

        if (!this.#hasPostsAppendedListener) {
          this.appEvents.on(
            "post-stream:posts-appended",
            this,
            this.#handlePostsAppended
          );
          this.#hasPostsAppendedListener = true;
        }
      }
    } finally {
      this.isLoading = false;
      this.loadTriggeredByIntersection = false;
    }
  }

  #getCurrentFocusContext(existingPostNumbers) {
    if (this.isLoadingAbove) {
      // For loading above, use the first available post from PostStream if provided
      const firstPostNumber =
        this.args.firstAvailablePost?.post_number ||
        (existingPostNumbers.length > 0
          ? Math.min(...existingPostNumbers)
          : null);

      return {
        direction: "above",
        nearestPost: firstPostNumber,
      };
    } else {
      // For loading below, use the last available post from PostStream if provided
      const lastPostNumber =
        this.args.lastAvailablePost?.post_number ||
        (existingPostNumbers.length > 0
          ? Math.max(...existingPostNumbers)
          : null);

      return {
        direction: "below",
        nearestPost: lastPostNumber,
      };
    }
  }

  #focusAppropriateNewPost(focusContext) {
    let targetPostNumber;

    if (focusContext.direction === "above") {
      targetPostNumber = focusContext.nearestPost - 1;
    } else {
      targetPostNumber = focusContext.nearestPost + 1;
    }

    // Try to find the target post heading first
    let targetElement = document.getElementById(
      `post-heading-${targetPostNumber}`
    );

    // Fallback to the post element if heading not found
    if (!targetElement) {
      targetElement = document.querySelector(
        `[data-post-number="${targetPostNumber}"]`
      );
    }

    this.accessibilityAnnouncer.announce(
      i18n("post.loading_complete"),
      "polite"
    );

    if (targetElement) {
      targetElement.focus();
    }
  }

  <template>
    <LoadMore
      @action={{this.handleIntersectionLoad}}
      @enabled={{this.enabled}}
      @rootMargin={{@rootMargin}}
      @threshold={{@threshold}}
      @root={{@root}}
      ...attributes
    >
      {{yield}}
    </LoadMore>

    {{! Screen reader accessible heading for navigation-based loading }}
    <div class="load-more-accessible sr-only">
      <h2 class="load-more-accessible__heading" id="load-more-heading">
        {{if this.isLoading (i18n "post.loading_more_posts") this.buttonLabel}}
      </h2>
    </div>
  </template>
}
