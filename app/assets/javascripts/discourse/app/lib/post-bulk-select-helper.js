import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { getOwner, setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { TrackedArray } from "@ember-compat/tracked-built-ins";

/**
 * Helper class for managing bulk selection of posts
 * Similar to BulkSelectHelper but specialized for posts
 *
 * Features:
 * - Individual post selection/deselection
 * - Select All / Clear All functionality
 * - Shift+click range selection (like topic lists)
 * - Bulk action execution
 */
export default class PostBulkSelectHelper {
  @service modal;

  @tracked loading = false;
  @tracked lastClickedPost = null;
  @tracked posts = null;
  selected = new TrackedArray();

  constructor(context, posts = null) {
    setOwner(this, getOwner(context));
    this.posts = posts;
  }

  /**
   * Update posts and clean up stale selections
   * @param {Array} newPosts - New posts array
   */
  updatePosts(newPosts) {
    this.posts = newPosts;
    this.#cleanupStaleSelections();
  }

  /**
   * Remove selections for posts that no longer exist
   */
  #cleanupStaleSelections() {
    if (!this.posts) {
      this.selected.length = 0;
      return;
    }

    const validPostIds = new Set(
      this.posts.map((post) => this.getPostId(post))
    );
    const validSelections = this.selected.filter((selected) =>
      validPostIds.has(this.getPostId(selected))
    );

    // Only update if there are stale selections
    if (validSelections.length !== this.selected.length) {
      this.selected.length = 0;
      this.selected.push(...validSelections);

      // Clear last clicked if it's no longer valid
      if (
        this.lastClickedPost &&
        !validPostIds.has(this.getPostId(this.lastClickedPost))
      ) {
        this.lastClickedPost = null;
      }
    }
  }

  get selectedCount() {
    return this.selected.length;
  }

  get hasSelection() {
    return this.selected.length > 0;
  }

  get allSelected() {
    return this.posts && this.selected.length === this.posts.length;
  }

  @action
  selectPost(post) {
    if (!this.isSelected(post)) {
      this.selected.push(post);
    }
  }

  @action
  deselectPost(post) {
    const index = this.selected.findIndex(
      (p) => this.getPostId(p) === this.getPostId(post)
    );
    if (index > -1) {
      this.selected.splice(index, 1);
    }
  }

  @action
  togglePost(post, options = {}) {
    const { shiftKey = false } = options;

    if (shiftKey && this.lastClickedPost && this.posts) {
      this.selectRange(this.lastClickedPost, post);
    } else {
      if (this.isSelected(post)) {
        this.deselectPost(post);
      } else {
        this.selectPost(post);
      }
      this.lastClickedPost = post;
    }
  }

  selectRange(startPost, endPost) {
    if (!this.posts) {
      return;
    }

    const startIndex = this.posts.findIndex(
      (p) => this.getPostId(p) === this.getPostId(startPost)
    );
    const endIndex = this.posts.findIndex(
      (p) => this.getPostId(p) === this.getPostId(endPost)
    );

    if (startIndex === -1 || endIndex === -1) {
      return;
    }

    const minIndex = Math.min(startIndex, endIndex);
    const maxIndex = Math.max(startIndex, endIndex);

    // Select all posts in the range
    for (let i = minIndex; i <= maxIndex; i++) {
      const post = this.posts[i];
      if (post && !this.isSelected(post)) {
        this.selectPost(post);
      }
    }

    this.lastClickedPost = endPost;
  }

  @action
  selectAll() {
    if (this.posts) {
      this.selected.length = 0;
      this.selected.push(...this.posts);
    }
  }

  @action
  clearAll() {
    this.selected.length = 0;
    this.lastClickedPost = null;
  }

  isSelected(post) {
    return this.selected.some(
      (p) => this.getPostId(p) === this.getPostId(post)
    );
  }

  getPostId(post) {
    // Support different post types with different id paths
    return post.id || post.post_id || post.draft_key;
  }

  async performBulkAction(actionFn) {
    if (!this.hasSelection) {
      return;
    }

    this.loading = true;
    try {
      await actionFn(this.selected);
      this.clearAll();
    } finally {
      this.loading = false;
    }
  }
}
