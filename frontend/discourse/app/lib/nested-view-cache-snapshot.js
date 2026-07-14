import { enumerateTrackedEntries } from "discourse/lib/tracked-tools";

export const NESTED_VIEW_CACHE_FORMAT_VERSION = 2;

const EXCLUDED_RECORD_KEYS = new Set([
  "__munge",
  "__state",
  "__type",
  "_details",
  "actionByName",
  "actionType",
  "post",
  "post_stream",
  "postStream",
  "store",
  "topic",
]);

export function snapshotNestedModelData(modelData) {
  return {
    topic: snapshotRecord(modelData.topic, { includeDetails: true }),
    opPost: snapshotRecord(modelData.opPost),
    rootNodes: snapshotNodes(modelData.rootNodes),
    page: modelData.page,
    hasMoreRoots: modelData.hasMoreRoots,
    sort: modelData.sort,
    messageBusLastId: modelData.messageBusLastId,
    pinnedPostIds: snapshotValue(modelData.pinnedPostIds),
    postNumber: modelData.postNumber,
    context: modelData.context,
    contextMode: modelData.contextMode,
    contextChain: snapshotNode(modelData.contextChain),
    initialFocusedPath: snapshotNodes(modelData.initialFocusedPath),
    targetPostNumber: modelData.targetPostNumber,
    contextNoAncestors: modelData.contextNoAncestors,
    ancestorsTruncated: modelData.ancestorsTruncated,
    topAncestorPostNumber: modelData.topAncestorPostNumber,
    newRootPostIds: snapshotValue(modelData.newRootPostIds),
  };
}

export function hydrateNestedModelData(store, snapshot) {
  const topicSnapshot = { ...snapshot.topic };
  const topicDetails = topicSnapshot.details;
  delete topicSnapshot.details;

  const topic = createFreshRecord(store, "topic", topicSnapshot);
  if (topicDetails) {
    topic.details = topicDetails;
  }
  topic.set("is_nested_view", true);
  setFreshPostStream(store, topic);
  topic.details.set("topic", topic);

  return {
    topic,
    opPost: hydratePost(store, topic, snapshot.opPost),
    rootNodes: hydrateNodes(store, topic, snapshot.rootNodes),
    page: snapshot.page,
    hasMoreRoots: snapshot.hasMoreRoots,
    sort: snapshot.sort,
    messageBusLastId: snapshot.messageBusLastId,
    pinnedPostIds: snapshotValue(snapshot.pinnedPostIds) || [],
    postNumber: snapshot.postNumber,
    context: snapshot.context ?? null,
    contextMode: snapshot.contextMode,
    contextChain: hydrateNode(store, topic, snapshot.contextChain),
    initialFocusedPath: hydrateNodes(store, topic, snapshot.initialFocusedPath),
    targetPostNumber: snapshot.targetPostNumber,
    contextNoAncestors: snapshot.contextNoAncestors,
    ancestorsTruncated: snapshot.ancestorsTruncated,
    topAncestorPostNumber: snapshot.topAncestorPostNumber,
    newRootPostIds: snapshotValue(snapshot.newRootPostIds) || [],
  };
}

export function snapshotExpansionState(expansionState) {
  return [...(expansionState || new Map()).entries()].map(
    ([postNumber, state]) => [postNumber, snapshotValue(state)]
  );
}

export function hydrateExpansionState(snapshot) {
  return new Map(
    (snapshot || []).map(([postNumber, state]) => [
      postNumber,
      snapshotValue(state),
    ])
  );
}

export function snapshotFetchedChildrenCache(fetchedChildrenCache) {
  return [...(fetchedChildrenCache || new Map()).entries()].map(
    ([postNumber, entry]) => [
      postNumber,
      {
        childNodes: snapshotNodes(entry.childNodes),
        page: entry.page,
        hasMore: entry.hasMore,
        fetchedFromServer: entry.fetchedFromServer,
      },
    ]
  );
}

export function hydrateFetchedChildrenCache(store, topic, snapshot) {
  return new Map(
    (snapshot || []).map(([postNumber, entry]) => [
      postNumber,
      {
        childNodes: hydrateNodes(store, topic, entry.childNodes),
        page: entry.page,
        hasMore: entry.hasMore,
        fetchedFromServer: entry.fetchedFromServer,
      },
    ])
  );
}

function snapshotNodes(nodes) {
  return nodes?.map((node) => snapshotNode(node)).filter(Boolean) || [];
}

function snapshotNode(node) {
  if (!node) {
    return null;
  }

  return {
    post: snapshotRecord(node.post),
    children: snapshotNodes(node.children),
    _renderKey: node._renderKey,
  };
}

function hydrateNodes(store, topic, nodes) {
  return (
    nodes?.map((node) => hydrateNode(store, topic, node)).filter(Boolean) || []
  );
}

function hydrateNode(store, topic, node) {
  if (!node) {
    return null;
  }

  const post = hydratePost(store, topic, node.post);
  return {
    post,
    children: hydrateNodes(store, topic, node.children),
    _renderKey: node._renderKey || post?.id,
  };
}

function hydratePost(store, topic, snapshot) {
  if (!snapshot) {
    return null;
  }

  const post = createFreshRecord(store, "post", snapshot);
  post.topic = topic;
  return registerFreshPostInTopicPostStream(topic, post);
}

function snapshotRecord(record, { includeDetails = false } = {}) {
  if (!record) {
    return null;
  }

  const snapshot = {};
  const entries = [
    ...Object.keys(record).map((key) => [key, record[key]]),
    ...enumerateTrackedEntries(record),
  ];

  for (const [key, value] of entries) {
    if (
      EXCLUDED_RECORD_KEYS.has(key) ||
      value === undefined ||
      typeof value === "function"
    ) {
      continue;
    }

    snapshot[key] = snapshotValue(value);
  }

  if (includeDetails) {
    snapshot.details = snapshotRecord(record.details);
  }

  return snapshot;
}

export function isValidNestedViewCacheSnapshot(snapshot) {
  return Boolean(
    snapshot?.topic &&
    isPlainCacheRecord(snapshot.topic) &&
    Array.isArray(snapshot.rootNodes) &&
    snapshot.rootNodes.every(isValidSnapshotNode)
  );
}

function isValidSnapshotNode(node) {
  return Boolean(
    node &&
    isPlainCacheRecord(node.post) &&
    Array.isArray(node.children) &&
    node.children.every(isValidSnapshotNode)
  );
}

function isPlainCacheRecord(record) {
  return Boolean(
    record &&
    typeof record === "object" &&
    !record.store &&
    !record.__type &&
    typeof record.get !== "function"
  );
}

function createFreshRecord(store, type, attrs) {
  return store._build(type, { ...attrs });
}

function setFreshPostStream(store, topic) {
  const postStream = createFreshRecord(store, "postStream", {
    id: topic.id,
    topic,
  });

  Object.defineProperty(topic, "postStream", {
    configurable: true,
    value: postStream,
  });
}

function registerFreshPostInTopicPostStream(topic, post) {
  const postStream = topic?.postStream;
  if (!postStream) {
    return post;
  }

  const storedPost = postStream.storePost(post);
  if (!storedPost) {
    return storedPost;
  }

  if (postStream.posts && !postStream.posts.includes(storedPost)) {
    postStream.posts.push(storedPost);
  }

  if (
    postStream.stream &&
    storedPost.id != null &&
    !postStream.stream.includes(storedPost.id)
  ) {
    postStream.stream.push(storedPost.id);
  }

  return storedPost;
}

function snapshotValue(value, seen = new WeakSet()) {
  if (value === null || value === undefined || typeof value !== "object") {
    return value;
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (seen.has(value)) {
    return undefined;
  }
  seen.add(value);

  if (Array.isArray(value)) {
    return value.map((item) => snapshotValue(item, seen));
  }

  if (value instanceof Map) {
    return [...value.entries()].map(([key, item]) => [
      key,
      snapshotValue(item, seen),
    ]);
  }

  const snapshot = {};
  for (const [key, item] of Object.entries(value)) {
    if (
      EXCLUDED_RECORD_KEYS.has(key) ||
      typeof item === "function" ||
      item === undefined
    ) {
      continue;
    }

    snapshot[key] = snapshotValue(item, seen);
  }

  return snapshot;
}
