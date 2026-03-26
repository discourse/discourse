import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import processNode from "../lib/process-node";
import NestedPost from "./nested-post";

export default class NestedPostChildren extends Component {
  @service appEvents;
  @service store;
  @service siteSettings;

  @tracked childNodes = [];
  @tracked loading = false;
  @tracked page = 0;
  @tracked hasMore = false;
  @tracked loadingMore = false;
  @tracked loaded = false;

  // Tracks whether we've fetched from the server yet (vs only having preloaded data)
  _fetchedFromServer = false;

  constructor() {
    super(...arguments);
    this.appEvents.on(
      "nested-replies:child-created",
      this,
      this._onChildCreated
    );

    const cached = this.args.fetchedChildrenCache?.get(
      this.args.parentPostNumber
    );
    if (cached) {
      this.childNodes = cached.childNodes;
      this.page = cached.page;
      this.hasMore = cached.hasMore;
      this.loaded = true;
      this._fetchedFromServer = cached.fetchedFromServer;
      return;
    }

    if (this.args.preloadedChildren?.length > 0) {
      this.childNodes = this.args.preloadedChildren;
      this.loaded = true;
      // When cap is ON at last level, the children endpoint returns flattened
      // descendants, so use total_descendant_count for the "more" threshold.
      const flatten =
        this.siteSettings.nested_replies_cap_nesting_depth &&
        this.childDepth >= this.siteSettings.nested_replies_max_depth;
      const expectedCount = flatten
        ? this.args.totalDescendantCount || this.args.directReplyCount || 0
        : this.args.directReplyCount || 0;
      this.hasMore = expectedCount > this.args.preloadedChildren.length;
    } else if (this.args.directReplyCount > 0) {
      this.loadChildren();
    }
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.appEvents.off(
      "nested-replies:child-created",
      this,
      this._onChildCreated
    );
    this._reportToCache();
  }

  _reportToCache() {
    if (!this.loaded || !this.args.fetchedChildrenCache) {
      return;
    }
    this.args.fetchedChildrenCache.set(this.args.parentPostNumber, {
      childNodes: this.childNodes,
      page: this.page,
      hasMore: this.hasMore,
      fetchedFromServer: this._fetchedFromServer,
    });
  }

  _onChildCreated({ post, parentPostNumber }) {
    if (parentPostNumber !== this.args.parentPostNumber) {
      return;
    }

    const alreadyExists = this.childNodes.some(
      (n) => n.post.id === post.id || n.post.post_number === post.post_number
    );
    if (alreadyExists) {
      return;
    }

    this.childNodes = [{ post, children: [] }, ...this.childNodes];
    this.loaded = true;
    this._reportToCache();
  }

  get childDepth() {
    return this.args.depth + 1;
  }

  get remainingCount() {
    const flatten =
      this.siteSettings.nested_replies_cap_nesting_depth &&
      this.childDepth >= this.siteSettings.nested_replies_max_depth;
    const total = flatten
      ? this.args.totalDescendantCount || this.args.directReplyCount || 0
      : this.args.directReplyCount || 0;
    return Math.max(total - this.childNodes.length, 0);
  }

  get loadMoreLabel() {
    const count = this.remainingCount;
    if (count > 0) {
      return i18n("nested_replies.load_more_children", { count });
    }
    return i18n("nested_replies.load_more_children_generic");
  }

  async loadChildren() {
    this.loading = true;
    try {
      const data = await ajax(
        `/n/${this.args.topic.slug}/${this.args.topic.id}/children/${this.args.parentPostNumber}.json?sort=${this.args.sort || "top"}&depth=${this.childDepth}`
      );
      if (this.isDestroying || this.isDestroyed) {
        return;
      }
      this.childNodes = (data.children || []).map((child) =>
        this._processNode(child)
      );
      this.page = data.page;
      this.hasMore = data.has_more || false;
      this.loaded = true;
      this._fetchedFromServer = true;
      this._reportToCache();
    } catch (e) {
      if (!(this.isDestroying || this.isDestroyed)) {
        popupAjaxError(e);
      }
    } finally {
      if (!(this.isDestroying || this.isDestroyed)) {
        this.loading = false;
      }
    }
  }

  @action
  async loadMore() {
    if (this.loadingMore || !this.hasMore) {
      return;
    }

    this.loadingMore = true;
    try {
      // First server fetch after preloaded data: get page 0 and merge
      // to preserve expanded state on already-loaded nodes.
      // Subsequent fetches: normal pagination.
      const nextPage = this._fetchedFromServer ? this.page + 1 : 0;
      const data = await ajax(
        `/n/${this.args.topic.slug}/${this.args.topic.id}/children/${this.args.parentPostNumber}.json?page=${nextPage}&sort=${this.args.sort || "top"}&depth=${this.childDepth}`
      );
      if (this.isDestroying || this.isDestroyed) {
        return;
      }
      const newNodes = (data.children || []).map((child) =>
        this._processNode(child)
      );

      if (!this._fetchedFromServer) {
        // Merge: keep preloaded children (may have expanded subtrees),
        // append only siblings not already present.
        const existing = new Set(
          this.childNodes.map((n) => n.post.post_number)
        );
        const additional = newNodes.filter(
          (n) => !existing.has(n.post.post_number)
        );
        this.childNodes = [...this.childNodes, ...additional];
        this._fetchedFromServer = true;
      } else {
        this.childNodes = [...this.childNodes, ...newNodes];
      }

      this.page = data.page;
      this.hasMore = data.has_more || false;
      this._reportToCache();
    } catch (e) {
      if (!(this.isDestroying || this.isDestroyed)) {
        popupAjaxError(e);
      }
    } finally {
      if (!(this.isDestroying || this.isDestroyed)) {
        this.loadingMore = false;
      }
    }
  }

  _processNode(nodeData) {
    return processNode(this.store, this.args.topic, nodeData);
  }

  <template>
    <div class="nested-post-children">
      <ConditionalLoadingSpinner @condition={{this.loading}}>
        {{#each this.childNodes as |node|}}
          <NestedPost
            @post={{node.post}}
            @children={{node.children}}
            @topic={{@topic}}
            @depth={{this.childDepth}}
            @sort={{@sort}}
            @defaultCollapsed={{@defaultCollapsed}}
            @replyToPost={{@replyToPost}}
            @editPost={{@editPost}}
            @deletePost={{@deletePost}}
            @recoverPost={{@recoverPost}}
            @showFlags={{@showFlags}}
            @showHistory={{@showHistory}}
            @collapseParent={{@collapseParent}}
            @highlightParentLine={{@highlightParentLine}}
            @unhighlightParentLine={{@unhighlightParentLine}}
            @parentLineHighlighted={{@parentLineHighlighted}}
            @expansionState={{@expansionState}}
            @fetchedChildrenCache={{@fetchedChildrenCache}}
            @scrollAnchor={{@scrollAnchor}}
            @registerPost={{@registerPost}}
          />
        {{/each}}

        {{#if this.hasMore}}
          <DButton
            class="btn-flat nested-post-children__load-more"
            @action={{this.loadMore}}
            @disabled={{this.loadingMore}}
            @translatedLabel={{this.loadMoreLabel}}
          />
        {{/if}}
      </ConditionalLoadingSpinner>
    </div>
  </template>
}
