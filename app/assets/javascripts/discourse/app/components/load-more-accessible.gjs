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
 */
export default class LoadMoreAccessible extends Component {
  @service capabilities;

  @tracked isLoading = false;

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

  get buttonLabel() {
    if (this.args.loadingText) {
      return this.args.loadingText;
    }

    return this.isLoadingAbove
      ? i18n("post.load_more_posts_above")
      : i18n("post.load_more_posts_below");
  }

  get buttonAriaLabel() {
    return this.isLoadingAbove
      ? i18n("post.sr_load_more_posts_above")
      : i18n("post.sr_load_more_posts_below");
  }

  @action
  async handleIntersectionLoad() {
    return this.#loadWithFocusManagement();
  }

  async #loadWithFocusManagement() {
    if (!this.enabled || !this.canLoadMore || this.isLoading) {
      return;
    }

    try {
      this.isLoading = true;

      // Announce loading has started
      this.#announceLoading();

      // Get existing post numbers and current focus context before loading
      const existingPostNumbers = this.#getExistingPostNumbers();
      const currentFocusContext =
        this.#getCurrentFocusContext(existingPostNumbers);

      // Trigger the actual loading action
      await this.args.action();

      // After loading completes, move focus to the appropriate new post
      schedule("afterRender", () => {
        setTimeout(() => {
          this.#focusAppropriateNewPost(
            existingPostNumbers,
            currentFocusContext
          );
        }, 300);
      });
    } finally {
      this.isLoading = false;
    }
  }

  #getCurrentFocusContext(existingPostNumbers) {
    if (this.isLoadingAbove) {
      // For loading above, find all posts in DOM order and get the first one
      // (since new posts will be inserted above it)
      const allPostElements = Array.from(
        document.querySelectorAll("[data-post-number]")
      );
      const firstPostNumber =
        allPostElements.length > 0
          ? parseInt(allPostElements[0].dataset.postNumber, 10)
          : Math.min(...existingPostNumbers);

      return {
        direction: "above",
        nearestPost: firstPostNumber,
        allExistingInOrder: allPostElements.map((el) =>
          parseInt(el.dataset.postNumber, 10)
        ),
      };
    } else {
      // For loading below, find all posts in DOM order and get the last one
      // (since new posts will be inserted below it)
      const allPostElements = Array.from(
        document.querySelectorAll("[data-post-number]")
      );
      const lastPostNumber =
        allPostElements.length > 0
          ? parseInt(
              allPostElements[allPostElements.length - 1].dataset.postNumber,
              10
            )
          : Math.max(...existingPostNumbers);

      return {
        direction: "below",
        nearestPost: lastPostNumber,
        allExistingInOrder: allPostElements.map((el) =>
          parseInt(el.dataset.postNumber, 10)
        ),
      };
    }
  }

  #announceLoading() {
    const announcement = document.createElement("div");
    announcement.setAttribute("aria-live", "assertive");
    announcement.className = "sr-only";
    announcement.textContent = this.isLoadingAbove
      ? "Loading more posts above..."
      : "Loading more posts below...";
    document.body.appendChild(announcement);

    setTimeout(() => {
      if (document.body.contains(announcement)) {
        document.body.removeChild(announcement);
      }
    }, 2000);
  }

  #getExistingPostNumbers() {
    return Array.from(document.querySelectorAll("[data-post-number]"))
      .map((el) => parseInt(el.dataset.postNumber, 10))
      .filter((num) => !isNaN(num));
  }

  #focusAppropriateNewPost(previousPostNumbers, focusContext) {
    // Find all current posts
    const currentPostNumbers = this.#getExistingPostNumbers();

    // Find newly loaded posts
    const newPostNumbers = currentPostNumbers.filter(
      (num) => !previousPostNumbers.includes(num)
    );

    if (newPostNumbers.length === 0) {
      return;
    }

    // Find the logical continuation post by looking at actual DOM order
    let targetPostNumber;

    // Get all posts (existing + new) in current DOM order
    const allCurrentElements = Array.from(
      document.querySelectorAll("[data-post-number]")
    );
    const allCurrentNumbers = allCurrentElements.map((el) =>
      parseInt(el.dataset.postNumber, 10)
    );

    if (focusContext.direction === "above") {
      // For loading above: find the new post that's now immediately before the first existing post
      const firstExistingPost = focusContext.nearestPost;
      const firstExistingIndex = allCurrentNumbers.indexOf(firstExistingPost);

      if (firstExistingIndex > 0) {
        // Focus on the post that's now just before the first existing post
        targetPostNumber = allCurrentNumbers[firstExistingIndex - 1];
      } else {
        // Fallback: focus on the highest new post
        targetPostNumber = Math.max(...newPostNumbers);
      }
    } else {
      // For loading below: find the new post that's now immediately after the last existing post
      const lastExistingPost = focusContext.nearestPost;
      const lastExistingIndex = allCurrentNumbers.indexOf(lastExistingPost);

      if (
        lastExistingIndex >= 0 &&
        lastExistingIndex < allCurrentNumbers.length - 1
      ) {
        // Focus on the post that's now just after the last existing post
        targetPostNumber = allCurrentNumbers[lastExistingIndex + 1];
      } else {
        // Fallback: focus on the lowest new post
        targetPostNumber = Math.min(...newPostNumbers);
      }
    }

    const targetHeading = document.getElementById(
      `post-heading-${targetPostNumber}`
    );

    if (targetHeading) {
      // Focus on the new post heading
      targetHeading.focus();

      // Ensure it's visible
      targetHeading.scrollIntoView({
        behavior: "auto",
        block: "start",
      });

      // Announce the successful navigation with direction context
      const announcement = document.createElement("div");
      announcement.setAttribute("aria-live", "assertive");
      announcement.className = "sr-only";
      announcement.textContent =
        focusContext.direction === "above"
          ? `Moved to post ${targetPostNumber}. ${newPostNumbers.length} new posts loaded above.`
          : `Moved to post ${targetPostNumber}. ${newPostNumbers.length} new posts loaded below.`;
      document.body.appendChild(announcement);

      setTimeout(() => {
        if (document.body.contains(announcement)) {
          document.body.removeChild(announcement);
        }
      }, 3000);
    }
  }

  <template>
    {{! Standard intersection-observer based loading for sighted users }}
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
    <div class="load-more-accessible">
      <h2
        class="load-more-accessible__heading"
        tabindex="0"
        id="load-more-heading"
      >
        {{if this.isLoading "Loading more posts..." this.buttonLabel}}
      </h2>
    </div>
  </template>
}
