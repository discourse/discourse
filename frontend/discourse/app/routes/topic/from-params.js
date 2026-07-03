import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { schedule } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import EmbedMode from "discourse/lib/embed-mode";
import { isTesting } from "discourse/lib/environment";
import {
  processNestedContextResponse,
  processNestedRootResponse,
} from "discourse/lib/nested-topic-model";
import {
  hydrateExpansionState,
  hydrateFetchedChildrenCache,
  hydrateNestedModelData,
  isValidNestedViewCacheSnapshot,
  NESTED_VIEW_CACHE_FORMAT_VERSION,
} from "discourse/lib/nested-view-cache-snapshot";
import PreloadStore from "discourse/lib/preload-store";
import { registerPostInTopicPostStream } from "discourse/lib/process-node";
import DiscourseURL from "discourse/lib/url";
import Draft from "discourse/models/draft";
import DiscourseRoute from "discourse/routes/discourse";

export function nestedQueryString(params) {
  const query = new URLSearchParams();

  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== null) {
      query.set(key, value);
    }
  }

  return query.toString();
}

// This route is used for retrieving a topic based on params
export default class TopicFromParams extends DiscourseRoute {
  @service appEvents;
  @service composer;
  @service header;
  @service historyStore;
  @service nestedViewCache;
  @service router;
  @service screenTrack;
  @service site;
  @service siteSettings;
  @service store;

  buildRouteInfoMetadata() {
    return {
      scrollOnTransition: false,
    };
  }

  // Avoid default model hook
  model(params, transition) {
    params = params || {};
    params.track_visit = true;

    const topic = this.modelFor("topic");

    const queryParams = transition?.to?.queryParams || {};
    if (topic.is_nested_view) {
      return this.#loadNestedModel(topic, params, queryParams).catch((e) => {
        if (!isTesting()) {
          // eslint-disable-next-line no-console
          console.log("Could not view nested topic", e);
        }
        params._loading_error = true;
        return params;
      });
    }

    const postStream = topic.postStream;

    // I sincerely hope no topic gets this many posts
    if (params.nearPost === "last") {
      params.nearPost = 999999999;
    }
    params.forceLoad = true;

    return postStream
      .refresh(params)
      .then(() => {
        if (topic.is_nested_view) {
          return this.#loadNestedModel(topic, params, queryParams);
        }
        return params;
      })
      .catch((e) => {
        if (!isTesting()) {
          // eslint-disable-next-line no-console
          console.log("Could not view topic", e);
        }
        params._loading_error = true;
        return params;
      });
  }

  afterModel(model) {
    const topic = this.modelFor("topic");

    if (model._nested) {
      this.header.enterTopic(model._nested.topic, !model._nested.contextMode);
      return;
    }

    const isLoadingFirstPost =
      topic.postStream.firstPostPresent &&
      !(model.nearPost && model.nearPost > 1);
    this.header.enterTopic(topic, isLoadingFirstPost);
  }

  deactivate() {
    super.deactivate(...arguments);

    const topicController = this.controllerFor("topic");
    const nestedController = this.controllerFor("nested");
    this.#saveNestedToCache(nestedController);

    topicController.unsubscribe();
    this.#resetTopicControllerBulkSelection(topicController);
    nestedController.unsubscribe();
    nestedController.topic = null;
  }

  setupController(controller, params, { _discourse_anchor }) {
    // Don't do anything else if we couldn't load
    // TODO: Tests require this but it seems bad
    if (params._loading_error) {
      return;
    }

    if (params._nested) {
      this.#setupNestedController(params._nested);
      return;
    }

    const topicController = this.controllerFor("topic");
    const nestedController = this.controllerFor("nested");
    const wasNestedView = Boolean(nestedController.topic);
    if (wasNestedView) {
      this.#saveNestedToCache(nestedController);
    }
    nestedController.unsubscribe();
    if (wasNestedView) {
      this.#resetTopicControllerBulkSelection(topicController);
      nestedController.topic = null;
    }
    const topic = this.modelFor("topic");
    const postStream = topic.postStream;

    // TODO we are seeing errors where closest post is null and this is exploding
    // we need better handling and logging for this condition.

    // there are no closestPost for hidden topics
    if (topic.view_hidden) {
      return;
    }

    // The post we requested might not exist. Let's find the closest post
    const closestPost = postStream.closestPostForPostNumber(
      params.nearPost || 1
    );
    const closest = closestPost.post_number;

    topicController.setProperties({
      "model.currentPost": closest,
      enteredIndex: topic.postStream.progressIndexOfPost(closestPost),
      enteredAt: Date.now().toString(),
      userLastReadPostNumber: topic.last_read_post_number,
      highestPostNumber: topic.highest_post_number,
    });

    this.appEvents.trigger("page:topic-loaded", topic);
    topicController.subscribe();
    if (wasNestedView) {
      this.screenTrack.start(topic.id, topicController);
    }

    // Highlight our post after the next render
    schedule("afterRender", () =>
      this.appEvents.trigger("post:highlight", closest)
    );

    const opts = {};
    if (document.location.hash) {
      opts.anchor = document.location.hash.slice(1);
    } else if (_discourse_anchor) {
      opts.anchor = _discourse_anchor;
    }
    DiscourseURL.jumpToPost(closest, opts);

    // completely clear out all the bookmark related attributes
    // because they are not in the response if bookmarked == false
    if (closestPost && !closestPost.bookmarked) {
      closestPost.clearBookmark();
    }

    if (!isEmpty(topic.draft) && !EmbedMode.enabled) {
      this.composer.open({
        draft: Draft.getLocal(topic.draft_key, topic.draft),
        draftKey: topic.draft_key,
        draftSequence: topic.draft_sequence,
        ignoreIfChanged: true,
        topic,
      });
    }
  }

  async #loadNestedModel(topic, params, queryParams) {
    const sort =
      queryParams.sort ||
      this.siteSettings.nested_replies_default_sort ||
      "top";
    const postNumber = Number(params.nearPost);
    const targetsPost = Number.isInteger(postNumber) && postNumber > 1;
    const slug = topic.slug || params.slug || "topic";
    const nestedParams = {
      ...params,
      post_number: targetsPost ? postNumber : null,
      context: queryParams.context,
    };

    const cacheKey = this.nestedViewCache.buildKey(topic.id, {
      ...nestedParams,
      sort,
    });
    const cached = this.#restoreNestedFromCache(cacheKey);

    if (cached) {
      params._nested = cached;
      params._nested.collapseReplies = this.#truthyQueryParam(
        queryParams.collapse_replies || queryParams.collapseReplies
      );
      return params;
    }

    if (targetsPost) {
      const query = nestedQueryString({
        sort,
        track_visit: true,
        context: queryParams.context,
      });

      const data = await PreloadStore.getAndRemove(
        `nested_topic_${topic.id}`,
        () => ajax(`/n/${slug}/${topic.id}/context/${postNumber}.json?${query}`)
      );

      params._nested = processNestedContextResponse({
        data,
        params: nestedParams,
        site: this.site,
        sort,
        store: this.store,
      });
    } else {
      const query = nestedQueryString({ sort, track_visit: true });
      const data = await PreloadStore.getAndRemove(
        `nested_topic_${topic.id}`,
        () => ajax(`/n/${slug}/${topic.id}.json?${query}`)
      );

      params._nested = processNestedRootResponse({
        data,
        params: nestedParams,
        site: this.site,
        siteSettings: this.siteSettings,
        store: this.store,
      });
    }

    const scrollAnchor = this.#loadScrollAnchor(cacheKey);
    if (scrollAnchor) {
      this._restoringFromCache = {
        expansionState: new Map(),
        fetchedChildrenCache: new Map(),
        scrollAnchor,
      };
    }

    params._nested.collapseReplies = this.#truthyQueryParam(
      queryParams.collapse_replies || queryParams.collapseReplies
    );

    return params;
  }

  #restoreNestedFromCache(cacheKey) {
    const cached = this.nestedViewCache.get(cacheKey);
    if (!cached) {
      this._restoringFromCache = null;
      return null;
    }

    const shouldRestore = this.nestedViewCache.consumeTraversal({
      allowLocalSignal: true,
      isPoppedState: this.historyStore.isPoppedState,
    });

    if (!shouldRestore) {
      this._restoringFromCache = null;
      return null;
    }

    const restored = this.#hydrateCachedEntry(cached);
    if (!restored) {
      this.nestedViewCache.remove(cacheKey);
      this._restoringFromCache = null;
      return null;
    }

    this._restoringFromCache = restored;
    return restored.modelData;
  }

  #scrollAnchorKey(cacheKey) {
    return `nested-view-scroll:${cacheKey}`;
  }

  #loadScrollAnchor(cacheKey) {
    try {
      const value = sessionStorage.getItem(this.#scrollAnchorKey(cacheKey));
      return value ? JSON.parse(value) : null;
    } catch {
      return null;
    }
  }

  #hydrateCachedEntry(cached) {
    if (
      cached.formatVersion !== NESTED_VIEW_CACHE_FORMAT_VERSION ||
      !isValidNestedViewCacheSnapshot(cached.modelData)
    ) {
      return null;
    }

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

  #setupNestedController(model) {
    const topicController = this.controllerFor("topic");
    const nestedController = this.controllerFor("nested");

    const restoringFromCache = this._restoringFromCache;

    if (!this.#teardownCurrentNestedTopic(nestedController, model.topic.id)) {
      nestedController.unsubscribe();
    }

    topicController.set("model", model.topic);
    this.#resetTopicControllerBulkSelection(topicController);
    topicController.setProperties({
      enteredAt: Date.now().toString(),
      userLastReadPostNumber: model.topic.last_read_post_number,
      highestPostNumber: model.topic.highest_post_number,
      sort: model.sort,
      context: model.context ?? (model.contextNoAncestors ? 0 : null),
      collapseReplies: model.collapseReplies,
    });

    if (restoringFromCache) {
      nestedController.expansionState = restoringFromCache.expansionState;
      nestedController.fetchedChildrenCache =
        restoringFromCache.fetchedChildrenCache;
      nestedController.scrollAnchor = restoringFromCache.scrollAnchor;
      this._restoringFromCache = null;
    } else {
      nestedController.expansionState = new Map();
      nestedController.fetchedChildrenCache = new Map();
      nestedController.scrollAnchor = null;
    }

    nestedController.setProperties(model);

    // Set the topic route's currentModel so route actions that call
    // this.modelFor("topic") (e.g. showFeatureTopic, showTopicTimerModal)
    // find the hydrated topic.
    getOwner(this).lookup("route:topic").currentModel = model.topic;

    // The Topic details setter replaces _details without preserving the
    // back-reference to the parent topic. Restore it so that
    // topic.details.updateNotifications() can construct the correct URL.
    model.topic.details.set("topic", model.topic);

    // Store the OP in the postStream so core components that read loaded posts
    // (e.g. share modal's "reply as new topic", bulk selection) find it.
    if (model.opPost && model.topic.postStream) {
      registerPostInTopicPostStream(model.topic, model.opPost);
    }

    this.appEvents.trigger("page:topic-loaded", model.topic);
    topicController.subscribe();
    nestedController.subscribe();
    this.screenTrack.start(model.topic.id, nestedController);

    if (!isEmpty(model.topic.draft) && !EmbedMode.enabled) {
      this.composer.open({
        draft: Draft.getLocal(model.topic.draft_key, model.topic.draft),
        draftKey: model.topic.draft_key,
        draftSequence: model.topic.draft_sequence,
        ignoreIfChanged: true,
        topic: model.topic,
      });
    }

    if (restoringFromCache?.scrollAnchor) {
      schedule("afterRender", () =>
        this.#restoreScrollAnchor(restoringFromCache.scrollAnchor)
      );
    } else if (!model.contextMode) {
      schedule("afterRender", () => window.scrollTo(0, 0));
    }
  }

  #restoreScrollAnchor(anchor) {
    if (Number.isFinite(anchor.scrollY)) {
      window.scrollTo(0, anchor.scrollY);
      return;
    }

    const article = document.querySelector(
      `.nested-post [data-post-number="${anchor.postNumber}"]`
    );
    const element = article?.closest(".nested-post") || article;
    if (element) {
      const rect = element.getBoundingClientRect();
      window.scrollTo(0, window.scrollY + rect.top - anchor.offsetFromTop);
    }
  }

  #teardownCurrentNestedTopic(controller, nextTopicId) {
    const currentTopicId = controller.topic?.id;

    if (!currentTopicId || String(currentTopicId) === String(nextTopicId)) {
      return false;
    }

    this.#saveNestedToCache(controller);
    controller.unsubscribe();
    this.screenTrack.stop();
    return true;
  }

  #saveNestedToCache(controller) {
    if (!controller.topic) {
      return;
    }

    const anchor = this.#findScrollAnchor();
    controller.saveToCache(anchor);
  }

  #findScrollAnchor() {
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
          scrollY: window.scrollY,
        };
      }
    }

    return best;
  }

  #resetTopicControllerBulkSelection(topicController) {
    topicController.set("multiSelect", false);
    topicController.selectedPostIds = [];
  }

  #truthyQueryParam(value) {
    return value === true || value === "true" || value === "1" || value === 1;
  }

  @action
  willTransition(transition) {
    this.controllerFor("topic").set("previousURL", document.location.pathname);

    transition.followRedirects().finally(() => {
      const routeName = this.router.currentRouteName;

      if (!routeName?.startsWith("topic.")) {
        this.header.clearTopic();
      }
    });

    // NOTE: omitting this return can break the back button when transitioning quickly between
    // topics and the latest page.
    return true;
  }
}
