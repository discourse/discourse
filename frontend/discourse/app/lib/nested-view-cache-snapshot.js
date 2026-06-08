export const NESTED_VIEW_CACHE_FORMAT_VERSION = 4;

const TOPIC_CACHE_FIELDS = [
  "id",
  "slug",
  "title",
  "fancy_title",
  "archetype",
  "category_id",
  "tags",
  "created_at",
  "deleted_at",
  "deleted_by",
  "visible",
  "closed",
  "archived",
  "pinned",
  "pinned_globally",
  "pinned_until",
  "unpinned",
  "unpinned_globally",
  "views",
  "posts_count",
  "reply_count",
  "highest_post_number",
  "last_read_post_number",
  "last_posted_at",
  "bumped_at",
  "chunk_size",
  "bookmarks",
  "draft",
  "draft_key",
  "draft_sequence",
  "details",
  "suggested_topics",
  "related_topics",
  "related_messages",
  "suggested_group_name",
];

const TOPIC_DETAILS_CACHE_FIELDS = [
  "id",
  "allowed_groups",
  "allowed_users",
  "can_create_post",
  "can_delete",
  "can_edit",
  "can_edit_staff_notes",
  "can_permanently_delete",
  "can_publish_page",
  "can_split_merge_topic",
  "created_by",
  "loaded",
  "notification_level",
  "notifications_reason_id",
  "participants",
];

const POST_CACHE_FIELDS = [
  "id",
  "post_number",
  "topic_id",
  "reply_to_post_number",
  "reply_count",
  "direct_reply_count",
  "total_descendant_count",
  "username",
  "name",
  "user_id",
  "user_title",
  "avatar_template",
  "primary_group_name",
  "trust_level",
  "created_at",
  "updated_at",
  "version",
  "cooked",
  "cooked_hidden",
  "excerpt",
  "actions_summary",
  "action_code",
  "action_code_path",
  "action_code_who",
  "admin",
  "badges_granted",
  "bookmarked",
  "can_delete",
  "can_edit",
  "can_permanently_delete",
  "can_recover",
  "can_see_hidden_post",
  "can_view_edit_history",
  "deleted_at",
  "deleted_by",
  "deleted_post_placeholder",
  "ignored_post_placeholder",
  "group_moderator",
  "hidden",
  "is_auto_generated",
  "is_localized",
  "language",
  "last_wiki_edit",
  "link_counts",
  "localization_outdated",
  "localized_oneboxes",
  "locked",
  "moderator",
  "notice",
  "notice_created_by_user",
  "post_localizations",
  "post_type",
  "quoted",
  "read",
  "readers_count",
  "reply_to_user",
  "staff",
  "staged",
  "title_is_group",
  "user_custom_fields",
  "user_deleted",
  "user_suspended",
  "via_email",
  "wiki",
  "yours",
];

const ACTION_SUMMARY_CACHE_FIELDS = [
  "id",
  "count",
  "hidden",
  "can_act",
  "acted",
  "can_undo",
  "can_defer_flags",
];

const SUGGESTED_TOPIC_KEYS = [
  "suggested_topics",
  "related_topics",
  "related_messages",
  "suggested_group_name",
];

const EXCLUDED_RECORD_KEYS = new Set([
  "__munge",
  "__state",
  "__type",
  "_details",
  "actionByName",
  "actionType",
  "children",
  "likeAction",
  "post",
  "post_stream",
  "postStream",
  "store",
  "topic",
]);

export function buildNestedViewCacheEntry(
  modelData,
  { expansionState, fetchedChildrenCache, scrollAnchor } = {}
) {
  return {
    formatVersion: NESTED_VIEW_CACHE_FORMAT_VERSION,
    payload: snapshotNestedPayload(modelData),
    uiState: {
      expansionState: snapshotExpansionState(expansionState),
      fetchedChildren: snapshotFetchedChildrenCache(fetchedChildrenCache),
      focusedPath: snapshotNodesAsPayload(modelData.initialFocusedPath),
      scrollAnchor: snapshotValue(scrollAnchor),
    },
  };
}

export function restoreNestedViewCacheEntry(entry) {
  if (!isValidNestedViewCacheEntry(entry)) {
    return null;
  }

  return {
    payload: cloneCacheValue(entry.payload),
    expansionState: restoreExpansionState(entry.uiState?.expansionState),
    fetchedChildren: cloneCacheValue(entry.uiState?.fetchedChildren) || [],
    focusedPath: cloneCacheValue(entry.uiState?.focusedPath) || [],
    scrollAnchor: cloneCacheValue(entry.uiState?.scrollAnchor),
  };
}

export function isValidNestedViewCacheEntry(entry) {
  return Boolean(
    entry?.formatVersion === NESTED_VIEW_CACHE_FORMAT_VERSION &&
    isValidNestedPayload(entry.payload) &&
    isValidMapSnapshot(entry.uiState?.expansionState) &&
    isValidMapSnapshot(entry.uiState?.fetchedChildren) &&
    isValidFocusedPathSnapshot(entry.uiState?.focusedPath)
  );
}

export function snapshotNestedPayload(modelData) {
  if (modelData.contextMode || modelData.postNumber) {
    return {
      contextMode: true,
      sort: modelData.sort,
      response: snapshotContextResponse(modelData),
    };
  }

  return {
    contextMode: false,
    response: snapshotRootResponse(modelData),
  };
}

export function snapshotExpansionState(expansionState) {
  return [...(expansionState || new Map()).entries()].map(
    ([postNumber, state]) => [postNumber, snapshotValue(state)]
  );
}

export function restoreExpansionState(snapshot) {
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
        children: snapshotNodesAsPayload(entry.childNodes),
        page: entry.page,
        hasMore: entry.hasMore,
        fetchedFromServer: entry.fetchedFromServer,
      },
    ]
  );
}

function snapshotRootResponse(modelData) {
  const response = {
    topic: snapshotTopic(modelData.topic),
    op_post: snapshotPost(modelData.opPost),
    roots: snapshotNodesAsPayload(modelData.rootNodes),
    page: modelData.page,
    has_more_roots: modelData.hasMoreRoots,
    sort: modelData.sort,
    message_bus_last_id: modelData.messageBusLastId,
    pinned_post_ids: snapshotValue(modelData.pinnedPostIds) || [],
  };

  copySuggestedTopicKeys(modelData.topic, response);
  return response;
}

function snapshotContextResponse(modelData) {
  const response = {
    topic: snapshotTopic(modelData.topic),
    op_post: snapshotPost(modelData.opPost),
    target_post: snapshotNodeAsPayload(findTargetNode(modelData)),
    ancestor_chain: snapshotAncestorChain(modelData),
    ancestors_truncated: modelData.ancestorsTruncated,
    message_bus_last_id: modelData.messageBusLastId,
  };

  copySuggestedTopicKeys(modelData.topic, response);
  return response;
}

function copySuggestedTopicKeys(topic, response) {
  for (const key of SUGGESTED_TOPIC_KEYS) {
    if (topic?.[key] !== undefined) {
      response[key] = snapshotValue(topic[key]);
    }
  }
}

function findTargetNode(modelData) {
  const targetPostNumber = modelData.targetPostNumber || modelData.postNumber;

  return (
    findNodeByPostNumber(modelData.contextChain, targetPostNumber) ||
    findNodeByPostNumber(modelData.initialFocusedPath, targetPostNumber) ||
    findNodeByPostNumber(modelData.rootNodes?.[0], targetPostNumber) ||
    modelData.contextChain ||
    modelData.rootNodes?.[0]
  );
}

function findNodeByPostNumber(nodeOrNodes, postNumber) {
  if (!nodeOrNodes || postNumber == null) {
    return null;
  }

  const nodes = Array.isArray(nodeOrNodes) ? nodeOrNodes : [nodeOrNodes];
  for (const node of nodes) {
    if (node?.post?.post_number === postNumber) {
      return node;
    }

    const childMatch = findNodeByPostNumber(node?.children, postNumber);
    if (childMatch) {
      return childMatch;
    }
  }

  return null;
}

function snapshotAncestorChain(modelData) {
  const targetPostNumber = modelData.targetPostNumber || modelData.postNumber;
  return (modelData.initialFocusedPath || [])
    .filter((node) => node?.post?.post_number !== targetPostNumber)
    .map((node) => snapshotPost(node.post))
    .filter(Boolean);
}

function isValidNestedPayload(payload) {
  return Boolean(
    payload &&
    typeof payload === "object" &&
    typeof payload.contextMode === "boolean" &&
    isValidNestedResponsePayload(payload.response, payload.contextMode)
  );
}

function isValidNestedResponsePayload(response, contextMode) {
  if (!response?.topic || !isPlainCacheRecord(response.topic)) {
    return false;
  }

  if (response.op_post && !isPlainCacheRecord(response.op_post)) {
    return false;
  }

  if (contextMode) {
    return Boolean(
      isValidPayloadNode(response.target_post) &&
      Array.isArray(response.ancestor_chain || []) &&
      (response.ancestor_chain || []).every(isPlainCacheRecord)
    );
  }

  return (
    Array.isArray(response.roots) && response.roots.every(isValidPayloadNode)
  );
}

function snapshotTopic(topic) {
  const snapshot = snapshotRecord(topic, TOPIC_CACHE_FIELDS);

  if (topic?.details) {
    snapshot.details = snapshotRecord(
      topic.details,
      TOPIC_DETAILS_CACHE_FIELDS
    );
  }

  return snapshot;
}

function snapshotPost(post) {
  const snapshot = snapshotRecord(post, POST_CACHE_FIELDS);

  if (Array.isArray(post?.actions_summary)) {
    snapshot.actions_summary = post.actions_summary.map((summary) =>
      snapshotRecord(summary, ACTION_SUMMARY_CACHE_FIELDS)
    );
  }

  return snapshot;
}

function snapshotNodesAsPayload(nodes) {
  return (
    nodes?.map((node) => snapshotNodeAsPayload(node)).filter(Boolean) || []
  );
}

function snapshotNodeAsPayload(node) {
  if (!node) {
    return null;
  }

  return {
    ...snapshotPost(node.post),
    children: snapshotNodesAsPayload(node.children),
    _renderKey: node._renderKey,
  };
}

function snapshotRecord(record, fields) {
  if (!record) {
    return null;
  }

  const snapshot = {};
  const keys = new Set([...Object.keys(record), ...fields]);

  for (const key of keys) {
    if (!shouldSnapshotRecordKey(record, key)) {
      continue;
    }

    snapshot[key] = snapshotValue(record[key]);
  }

  return snapshot;
}

function shouldSnapshotRecordKey(record, key) {
  if (EXCLUDED_RECORD_KEYS.has(key) || key.startsWith("__")) {
    return false;
  }

  const value = record[key];
  return value !== undefined && typeof value !== "function";
}

function cloneCacheValue(value) {
  if (value === undefined) {
    return undefined;
  }

  return JSON.parse(JSON.stringify(value));
}

function snapshotValue(value, seen = new WeakSet()) {
  if (value === undefined || typeof value === "function") {
    return undefined;
  }

  if (value === null || typeof value !== "object") {
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
    return value
      .map((item) => snapshotValue(item, seen))
      .filter((item) => item !== undefined);
  }

  const snapshot = {};
  for (const key of Object.keys(value)) {
    if (EXCLUDED_RECORD_KEYS.has(key) || key.startsWith("__")) {
      continue;
    }

    const item = snapshotValue(value[key], seen);
    if (item !== undefined) {
      snapshot[key] = item;
    }
  }
  return snapshot;
}

function isValidPayloadNode(node) {
  return Boolean(
    node &&
    isPlainCacheRecord(node) &&
    Array.isArray(node.children) &&
    node.children.every(isValidPayloadNode)
  );
}

function isPlainCacheRecord(record) {
  return Boolean(
    record &&
    typeof record === "object" &&
    !Array.isArray(record) &&
    !record.store &&
    !record.__type &&
    typeof record.get !== "function"
  );
}

function isValidFocusedPathSnapshot(snapshot) {
  return (
    snapshot === undefined ||
    (Array.isArray(snapshot) && snapshot.every(isValidPayloadNode))
  );
}

function isValidMapSnapshot(snapshot) {
  return snapshot === undefined || Array.isArray(snapshot);
}
