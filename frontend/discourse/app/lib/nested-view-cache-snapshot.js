import processNode, {
  registerPostInTopicPostStream,
} from "discourse/lib/process-node";
import { enumerateTrackedEntries } from "discourse/lib/tracked-tools";

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
  const topic = store.createRecord("topic", snapshot.topic);
  topic.set("is_nested_view", true);
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

  return processNode(store, topic, {
    ...node.post,
    children: node.children || [],
    _renderKey: node._renderKey,
  });
}

function hydratePost(store, topic, snapshot) {
  if (!snapshot) {
    return null;
  }

  const post = store.createRecord("post", snapshot);
  post.topic = topic;
  return registerPostInTopicPostStream(topic, post) || post;
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
    if (EXCLUDED_RECORD_KEYS.has(key) || typeof value === "function") {
      continue;
    }

    snapshot[key] = snapshotValue(value);
  }

  if (includeDetails) {
    snapshot.details = snapshotRecord(record.details);
  }

  return snapshot;
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
