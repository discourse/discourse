import processNode from "discourse/lib/process-node";

export function processNestedRootResponse({
  data,
  params,
  site,
  siteSettings,
  store,
}) {
  hydrateCategories(site, data);

  const topic = buildNestedTopic(store, data);
  const assignTopic = (postData) => buildPost(store, topic, postData);
  const opPost = data.op_post ? assignTopic(data.op_post) : null;
  const rootNodes = (data.roots || []).map((root) =>
    processNode(store, topic, root)
  );

  return {
    topic,
    opPost,
    rootNodes,
    page: data.page || 0,
    hasMoreRoots: data.has_more_roots || false,
    sort: data.sort || siteSettings.nested_replies_default_sort || "top",
    effectiveSort:
      data.effective_sort ||
      data.sort ||
      siteSettings.nested_replies_default_sort ||
      "top",
    messageBusLastId: data.message_bus_last_id,
    pinnedPostIds: data.pinned_post_ids || [],
    postNumber: params.post_number ? Number(params.post_number) : null,
    context: params.context ?? null,
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

export function processNestedContextResponse({
  data,
  params,
  sort,
  site,
  store,
}) {
  hydrateCategories(site, data);

  const topic = buildNestedTopic(store, data);
  const assignTopic = (postData) => buildPost(store, topic, postData);
  const opPost = data.op_post ? assignTopic(data.op_post) : null;

  const targetNode = processNode(store, topic, data.target_post);
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
    effectiveSort: data.effective_sort || sort,
    pinnedPostIds: [],
    messageBusLastId: data.message_bus_last_id,
    postNumber: Number(params.post_number),
    context: params.context ?? null,
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

function hydrateCategories(site, data) {
  // Match Topic.find: seed the site category store from the topic payload so
  // lazy_load_categories installs can resolve category badges on the topic
  // itself and on piggybacked suggested/related rows that only carry
  // category_id.
  data.topic?.categories?.forEach((category) => site.updateCategory(category));
}

function buildNestedTopic(store, data) {
  const topic = store.createRecord("topic", data.topic);
  topic.set("is_nested_view", true);

  // Suggested/related are piggybacked at top-level on whichever response has
  // has_more_roots=false.
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

  return topic;
}

function buildPost(store, topic, postData) {
  const post = store.createRecord("post", postData);
  post.topic = topic;
  return post;
}
