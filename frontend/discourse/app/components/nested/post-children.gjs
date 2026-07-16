import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import processNode from "../../lib/process-node";
import NestedPost from "./post";

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
  _identityKey = null;

  constructor() {
    super(...arguments);
    this.appEvents.on(
      "nested-replies:child-created",
      this,
      this._onChildCreated
    );

    this._hydrateFromArgs();
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

  get identityKey() {
    return [
      this.args.topic?.id,
      this.args.parentPostNumber,
      this.args.sort,
    ].join(":");
  }

  @action
  hydrateFromArgs() {
    this._hydrateFromArgs();
  }

  _cacheKey(parentPostNumber = this.args.parentPostNumber) {
    return `${this.args.topic?.id}:${parentPostNumber}`;
  }

  _hydrateFromArgs() {
    if (this._identityKey === this.identityKey) {
      return;
    }

    this._identityKey = this.identityKey;
    this.childNodes = [];
    this.loading = false;
    this.page = 0;
    this.hasMore = false;
    this.loadingMore = false;
    this.loaded = false;
    this._fetchedFromServer = false;

    const cached = this.args.fetchedChildrenCache?.get(this._cacheKey());
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

  _reportToCache(parentPostNumber = this.args.parentPostNumber) {
    if (!this.loaded || !parentPostNumber || !this.args.fetchedChildrenCache) {
      return;
    }
    this.args.fetchedChildrenCache.set(this._cacheKey(parentPostNumber), {
      childNodes: this.childNodes,
      page: this.page,
      hasMore: this.hasMore,
      fetchedFromServer: this._fetchedFromServer,
    });
  }

  _onChildCreated({ topicId, post, parentPostNumber }) {
    if (
      String(topicId) !== String(this.args.topic?.id) ||
      parentPostNumber !== this.args.parentPostNumber
    ) {
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
      const query = new URLSearchParams({
        sort: this.args.sort || "top",
        depth: this.childDepth,
      });
      const data = await ajax(
        `/n/${this.args.topic.slug}/${this.args.topic.id}/children/${this.args.parentPostNumber}.json?${query}`
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
      const query = new URLSearchParams({
        page: nextPage,
        sort: this.args.sort || "top",
        depth: this.childDepth,
      });
      const data = await ajax(
        `/n/${this.args.topic.slug}/${this.args.topic.id}/children/${this.args.parentPostNumber}.json?${query}`
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
    <div
      class="nested-post-children"
      {{didUpdate this.hydrateFromArgs @topic.id @parentPostNumber @sort}}
    >
      <DConditionalLoadingSpinner @condition={{this.loading}}>
        {{#each this.childNodes key="post.id" as |node|}}
          <NestedPost
            @post={{node.post}}
            @children={{node.children}}
            @topic={{@topic}}
            @depth={{this.childDepth}}
            @path={{@path}}
            @sort={{@sort}}
            @replyToPost={{@replyToPost}}
            @editPost={{@editPost}}
            @deletePost={{@deletePost}}
            @recoverPost={{@recoverPost}}
            @showFlags={{@showFlags}}
            @showHistory={{@showHistory}}
            @changeNotice={{@changeNotice}}
            @changePostOwner={{@changePostOwner}}
            @grantBadge={{@grantBadge}}
            @lockPost={{@lockPost}}
            @unlockPost={{@unlockPost}}
            @permanentlyDeletePost={{@permanentlyDeletePost}}
            @rebakePost={{@rebakePost}}
            @showPagePublish={{@showPagePublish}}
            @togglePostType={{@togglePostType}}
            @toggleWiki={{@toggleWiki}}
            @unhidePost={{@unhidePost}}
            @collapseParent={{@collapseParent}}
            @highlightParentLine={{@highlightParentLine}}
            @unhighlightParentLine={{@unhighlightParentLine}}
            @parentLineHighlighted={{@parentLineHighlighted}}
            @expansionState={{@expansionState}}
            @fetchedChildrenCache={{@fetchedChildrenCache}}
            @scrollAnchor={{@scrollAnchor}}
            @registerPost={{@registerPost}}
            @collapseFromDepth={{@collapseFromDepth}}
            @focusPost={{@focusPost}}
            @captureScrollAnchor={{@captureScrollAnchor}}
            @multiSelect={{@multiSelect}}
            @togglePostSelection={{@togglePostSelection}}
            @selectReplies={{@selectReplies}}
            @selectBelow={{@selectBelow}}
            @postSelected={{@postSelected}}
          />
        {{/each}}

        {{#if this.hasMore}}
          <DButton
            class={{dConcatClass
              "btn-flat"
              "nested-post-children__load-more"
              (if @parentLineHighlighted "--parent-line-highlighted")
            }}
            @action={{this.loadMore}}
            @disabled={{this.loadingMore}}
            @translatedLabel={{this.loadMoreLabel}}
          />
        {{/if}}
      </DConditionalLoadingSpinner>
    </div>
  </template>
}
