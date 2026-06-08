import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import MoveToTopicModal from "discourse/components/modal/move-to-topic";
import { ajax } from "discourse/lib/ajax";
import EmbedMode from "discourse/lib/embed-mode";
import {
  hydrateExpansionState,
  hydrateFetchedChildrenCache,
  hydrateNestedModelData,
} from "discourse/lib/nested-view-cache-snapshot";
import PreloadStore from "discourse/lib/preload-store";
import topicTitleToken from "discourse/lib/topic-title-token";
import Draft from "discourse/models/draft";
import DiscourseRoute from "discourse/routes/discourse";
import processNode, {
  registerPostInTopicPostStream,
} from "../lib/process-node";

export default class NestedRoute extends DiscourseRoute {
  @service composer;
  @service header;
  @service historyStore;
  @service modal;
  @service nestedViewCache;
  @service router;
  @service screenTrack;
  @service site;
  @service siteSettings;
  @service store;

  queryParams = {
    sort: { refreshModel: true },
    context: { refreshModel: true },
    collapseReplies: { refreshModel: false },
  };

  buildRouteInfoMetadata() {
    return { scrollOnTransition: false };
  }

  titleToken() {
    return topicTitleToken(this.currentModel?.topic, this.siteSettings);
  }

  async model(params, transition) {
    const { topic_id, slug, post_number } = params;
    this._teardownCurrentTopic(topic_id);

    const sort =
      params.sort || this.siteSettings.nested_replies_default_sort || "top";

    const cacheKey = this.nestedViewCache.buildKey(topic_id, {
      ...params,
      sort,
    });
    if (
      this.nestedViewCache.consumeTraversal({
        allowLocalSignal: transition?.from?.name?.startsWith("nested"),
        isPoppedState: this.historyStore.isPoppedState,
      })
    ) {
      const cached = this.nestedViewCache.get(cacheKey);
      if (cached) {
        const restored = this._hydrateCachedEntry(cached);
        this._restoringFromCache = restored;
        return restored.modelData;
      }
    }
    this._restoringFromCache = null;

    if (post_number) {
      const queryParts = [`sort=${sort}`, "track_visit=true"];
      if (params.context !== undefined && params.context !== null) {
        queryParts.push(`context=${params.context}`);
      }
      const contextQuery = `?${queryParts.join("&")}`;
      const data = await PreloadStore.getAndRemove(
        `nested_topic_${topic_id}`,
        () =>
          ajax(
            `/n/${slug}/${topic_id}/context/${post_number}.json${contextQuery}`
          )
      );
      return this._processContextResponse(data, params, sort);
    }

    const data = await PreloadStore.getAndRemove(
      `nested_topic_${topic_id}`,
      () => ajax(`/n/${slug}/${topic_id}.json?sort=${sort}&track_visit=true`)
    );
    return this._processResponse(data, params);
  }

  setupController(controller, model) {
    const restoringFromCache = this._restoringFromCache;

    if (restoringFromCache) {
      controller.expansionState = restoringFromCache.expansionState;
      controller.fetchedChildrenCache = restoringFromCache.fetchedChildrenCache;
      controller.scrollAnchor = restoringFromCache.scrollAnchor;
      this._restoringFromCache = null;
    } else {
      controller.expansionState = new Map();
      controller.fetchedChildrenCache = new Map();
      controller.scrollAnchor = null;
    }

    controller.setProperties(model);
    controller.subscribe();

    // Hydrate the topic controller so core components that do
    // lookup("controller:topic") (e.g. share modal) find valid state.
    const topicController = this.controllerFor("topic");
    topicController.set("model", model.topic);
    this._resetTopicControllerBulkSelection(topicController);

    // Set the topic route's currentModel so route actions that call
    // this.modelFor("topic") (e.g. showFeatureTopic, showTopicTimerModal)
    // find the topic instead of undefined.
    getOwner(this).lookup("route:topic").currentModel = model.topic;

    // The Topic details setter replaces _details without preserving the
    // back-reference to the parent topic. Restore it so that
    // topic.details.updateNotifications() can construct the correct URL.
    model.topic.details.set("topic", model.topic);

    this.header.enterTopic(model.topic, !model.contextMode);

    // Store the OP in the postStream so core components that read loaded posts
    // (e.g. share modal's "reply as new topic", bulk selection) find it.
    if (model.opPost && model.topic.postStream) {
      registerPostInTopicPostStream(model.topic, model.opPost);
    }

    this.screenTrack.start(model.topic.id, controller);

    if (!isEmpty(model.topic.draft) && !EmbedMode.enabled) {
      this.composer.open({
        draft: Draft.getLocal(model.topic.draft_key, model.topic.draft),
        draftKey: model.topic.draft_key,
        draftSequence: model.topic.draft_sequence,
        ignoreIfChanged: true,
        topic: model.topic,
      });
    }

    if (!restoringFromCache && !model.contextMode) {
      // Nested opts out of the global scroll manager for cache restoration,
      // so fresh root-topic entries need their own top reset.
      schedule("afterRender", () => window.scrollTo(0, 0));
    }
  }

  deactivate() {
    super.deactivate(...arguments);

    const controller = this.controller;
    this._saveToCache(controller);

    this._resetTopicControllerBulkSelection();
    controller.unsubscribe();
    this.screenTrack.stop();
    controller.topic = null;
  }

  @action
  willTransition(transition) {
    transition.followRedirects().finally(() => {
      const routeName = this.router.currentRouteName;

      if (
        !routeName?.startsWith("topic.") &&
        !routeName?.startsWith("nested")
      ) {
        this.header.clearTopic();
      }
    });

    return true;
  }

  @action
  moveToTopic() {
    const topicController = this.controllerFor("topic");
    this.modal.show(MoveToTopicModal, {
      model: {
        topic: this.modelFor("topic"),
        selectedPostsCount: topicController.selectedPostsCount,
        selectedAllPosts: false,
        selectedPosts: topicController.selectedPosts,
        selectedPostIds: topicController.selectedPostIds,
        toggleMultiSelect: topicController.toggleMultiSelect,
      },
    });
  }

  @action
  changeOwner(post = null) {
    return getOwner(this).lookup("route:topic").changeOwner(post);
  }

  _resetTopicControllerBulkSelection(
    topicController = this.controllerFor("topic")
  ) {
    topicController.set("multiSelect", false);
    topicController.selectedPostIds = [];
  }

  _saveToCache(controller) {
    if (!controller.topic) {
      return;
    }

    controller.saveToCache(this._findScrollAnchor());
  }

  _teardownCurrentTopic(nextTopicId) {
    const controller = this.controllerFor("nested");
    const currentTopicId = controller.topic?.id;

    if (!currentTopicId || String(currentTopicId) === String(nextTopicId)) {
      return;
    }

    this._saveToCache(controller);
    controller.unsubscribe();
    this.screenTrack.stop();
  }

  _findScrollAnchor() {
    const articles = document.querySelectorAll(
      ".nested-post [data-post-number]"
    );
    let best = null;
    let bestDistance = Infinity;

    for (const el of articles) {
      const rect = el.getBoundingClientRect();
      const distance = Math.abs(rect.top);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = {
          postNumber: Number(el.dataset.postNumber),
          offsetFromTop: rect.top,
        };
      }
    }
    return best;
  }

  _hydrateCachedEntry(cached) {
    const modelData = hydrateNestedModelData(this.store, cached.modelData);

    return {
      modelData,
      expansionState: hydrateExpansionState(cached.expansionState),
      fetchedChildrenCache: hydrateFetchedChildrenCache(
        this.store,
        modelData.topic,
        cached.fetchedChildrenCache
      ),
      scrollAnchor: cached.scrollAnchor,
    };
  }

  _processResponse(data, params) {
    // Match Topic.find: seed the site category store from the topic
    // payload so lazy_load_categories installs can resolve category
    // badges on the topic itself and on piggybacked suggested/related
    // rows that only carry category_id.
    data.topic?.categories?.forEach((c) => this.site.updateCategory(c));

    const topic = this.store.createRecord("topic", data.topic);
    topic.set("is_nested_view", true);

    // Suggested/related are piggybacked at top-level on whichever
    // response has has_more_roots=false — here, a short topic that
    // fits in one page; otherwise they arrive via loadMoreRoots.
    for (const key of [
      "suggested_topics",
      "related_topics",
      "related_messages",
      "suggested_group_name",
    ]) {
      if (data[key] !== undefined) {
        topic[key] = data[key];
      }
    }

    const assignTopic = (postData) => {
      const post = this.store.createRecord("post", postData);
      post.topic = topic;
      return post;
    };

    const opPost = data.op_post ? assignTopic(data.op_post) : null;

    const rootNodes = (data.roots || []).map((root) =>
      processNode(this.store, topic, root)
    );

    return {
      topic,
      opPost,
      rootNodes,
      page: data.page || 0,
      hasMoreRoots: data.has_more_roots || false,
      sort: data.sort || this.siteSettings.nested_replies_default_sort || "top",
      messageBusLastId: data.message_bus_last_id,
      pinnedPostIds: data.pinned_post_ids || [],
      postNumber: params.post_number ? Number(params.post_number) : null,
      contextMode: false,
      contextChain: null,
      initialFocusedPath: [],
      targetPostNumber: null,
      contextNoAncestors: false,
      ancestorsTruncated: false,
      topAncestorPostNumber: null,
      newRootPostIds: [],
      editingTopic: false,
    };
  }

  _processContextResponse(data, params, sort) {
    data.topic?.categories?.forEach((c) => this.site.updateCategory(c));

    const topic = this.store.createRecord("topic", data.topic);
    topic.set("is_nested_view", true);

    for (const key of [
      "suggested_topics",
      "related_topics",
      "related_messages",
      "suggested_group_name",
    ]) {
      if (data[key] !== undefined) {
        topic[key] = data[key];
      }
    }

    const assignTopic = (postData) => {
      const post = this.store.createRecord("post", postData);
      post.topic = topic;
      return post;
    };

    const opPost = data.op_post ? assignTopic(data.op_post) : null;

    const targetNode = processNode(this.store, topic, data.target_post);
    const ancestors = (data.ancestor_chain || []).map((a) => assignTopic(a));
    const targetReplyTo = targetNode.post.reply_to_post_number;
    const hasParentContext = targetReplyTo && targetReplyTo !== 1;
    const noAncestors = ancestors.length === 0 && hasParentContext;

    // Nest ancestors outermost-first so target ends up as the chain leaf.
    let chainTip = targetNode;
    const focusedPath = [targetNode];
    for (let i = ancestors.length - 1; i >= 0; i--) {
      chainTip = {
        post: ancestors[i],
        children: [chainTip],
        _renderKey: ancestors[i].id,
      };
      focusedPath.unshift(chainTip);
    }

    // Force full NestedPost rebuild on every fetch: NestedPostChildren reads
    // @preloadedChildren only in its constructor, so without a fresh key the
    // inner cascade keeps rendering the previous target when two context
    // views share a chain root.
    chainTip._renderKey = crypto.randomUUID();

    return {
      topic,
      opPost,
      sort,
      pinnedPostIds: [],
      messageBusLastId: data.message_bus_last_id,
      postNumber: Number(params.post_number),
      contextMode: true,
      contextChain: chainTip,
      initialFocusedPath: focusedPath,
      targetPostNumber: Number(params.post_number),
      contextNoAncestors: noAncestors,
      ancestorsTruncated: data.ancestors_truncated || false,
      topAncestorPostNumber:
        ancestors.length > 0 ? ancestors[0].post_number : null,
      rootNodes: [chainTip],
      page: 0,
      hasMoreRoots: false,
      newRootPostIds: [],
      editingTopic: false,
    };
  }
}
