import { getOwner } from "@ember/owner";
import Route from "@ember/routing/route";
import { service } from "@ember/service";
import { ajax } from "discourse/lib/ajax";
import processNode from "../lib/process-node";

export default class NestedRoute extends Route {
  @service nestedViewCache;
  @service screenTrack;
  @service siteSettings;
  @service store;

  queryParams = {
    sort: { refreshModel: true },
    context: { refreshModel: true },
  };

  buildRouteInfoMetadata() {
    return { scrollOnTransition: false };
  }

  async model(params) {
    const { topic_id, slug, post_number } = params;
    const sort =
      params.sort || this.siteSettings.nested_replies_default_sort || "top";

    const cacheKey = this.nestedViewCache.buildKey(topic_id, {
      ...params,
      sort,
    });
    if (this.nestedViewCache.consumeTraversal()) {
      const cached = this.nestedViewCache.get(cacheKey);
      if (cached) {
        this._restoringFromCache = cached;
        return cached.modelData;
      }
    }
    this._restoringFromCache = null;

    if (post_number) {
      const queryParts = [`sort=${sort}`];
      if (params.context !== undefined && params.context !== null) {
        queryParts.push(`context=${params.context}`);
      }
      const contextQuery = `?${queryParts.join("&")}`;
      const data = await ajax(
        `/n/${slug}/${topic_id}/context/${post_number}.json${contextQuery}`
      );
      return this._processContextResponse(data, params, sort);
    }

    const data = await ajax(`/n/${slug}/${topic_id}/roots.json?sort=${sort}`);
    return this._processResponse(data, params);
  }

  setupController(controller, model) {
    if (this._restoringFromCache) {
      controller.expansionState = this._restoringFromCache.expansionState;
      controller.fetchedChildrenCache =
        this._restoringFromCache.fetchedChildrenCache;
      controller.scrollAnchor = this._restoringFromCache.scrollAnchor;
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
    this.controllerFor("topic").set("model", model.topic);

    // Set the topic route's currentModel so route actions that call
    // this.modelFor("topic") (e.g. showFeatureTopic, showTopicTimerModal)
    // find the topic instead of undefined.
    getOwner(this).lookup("route:topic").currentModel = model.topic;

    // The Topic details setter replaces _details without preserving the
    // back-reference to the parent topic. Restore it so that
    // topic.details.updateNotifications() can construct the correct URL.
    model.topic.details.set("topic", model.topic);

    // Store the OP in the postStream so core components that call
    // postStream.findLoadedPost() (e.g. share modal's "reply as new topic")
    // find a valid post instead of undefined.
    if (model.opPost && model.topic.postStream) {
      model.topic.postStream.storePost(model.opPost);
    }

    this.screenTrack.start(model.topic.id, controller);
  }

  deactivate() {
    super.deactivate(...arguments);

    const controller = this.controller;
    this._saveToCache(controller);

    controller.unsubscribe();
    this.screenTrack.stop();
  }

  _saveToCache(controller) {
    if (!controller.topic) {
      return;
    }

    const cacheKey = this.nestedViewCache.buildKey(controller.topic.id, {
      sort: controller.sort,
      post_number: controller.postNumber,
      context: controller.contextNoAncestors ? 0 : undefined,
    });

    this.nestedViewCache.save(cacheKey, {
      modelData: {
        topic: controller.topic,
        opPost: controller.opPost,
        rootNodes: controller.rootNodes,
        page: controller.page,
        hasMoreRoots: controller.hasMoreRoots,
        sort: controller.sort,
        messageBusLastId: controller.messageBusLastId,
        pinnedPostNumber: controller.pinnedPostNumber,
        postNumber: controller.postNumber,
        contextMode: controller.contextMode,
        contextChain: controller.contextChain,
        targetPostNumber: controller.targetPostNumber,
        contextNoAncestors: controller.contextNoAncestors,
        ancestorsTruncated: controller.ancestorsTruncated,
        topAncestorPostNumber: controller.topAncestorPostNumber,
      },
      expansionState: new Map(controller.expansionState),
      fetchedChildrenCache: new Map(controller.fetchedChildrenCache),
      scrollAnchor: this._findScrollAnchor(),
    });
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

  _processResponse(data, params) {
    const topic = this.store.createRecord("topic", data.topic);

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
      pinnedPostNumber: data.pinned_post_number || null,
      postNumber: params.post_number ? Number(params.post_number) : null,
      contextMode: false,
      contextChain: null,
      targetPostNumber: null,
      contextNoAncestors: false,
      ancestorsTruncated: false,
      topAncestorPostNumber: null,
    };
  }

  _processContextResponse(data, params, sort) {
    const topic = this.store.createRecord("topic", data.topic);

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

    // Build nested chain: ancestor[0] -> ancestor[1] -> ... -> target
    // When context=0 (no ancestors), target becomes the chain root at depth 0.
    let chainTip = targetNode;
    for (let i = ancestors.length - 1; i >= 0; i--) {
      chainTip = { post: ancestors[i], children: [chainTip] };
    }

    return {
      topic,
      opPost,
      sort,
      messageBusLastId: data.message_bus_last_id,
      postNumber: Number(params.post_number),
      contextMode: true,
      contextChain: chainTip,
      targetPostNumber: Number(params.post_number),
      contextNoAncestors: noAncestors,
      ancestorsTruncated: data.ancestors_truncated || false,
      topAncestorPostNumber:
        ancestors.length > 0 ? ancestors[0].post_number : null,
      rootNodes: [],
      page: 0,
      hasMoreRoots: false,
    };
  }
}
