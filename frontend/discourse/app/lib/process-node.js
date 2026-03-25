/**
 * Recursively converts raw JSON node data from the nested endpoints
 * into { post, children } objects with proper Ember store records.
 *
 * @param {Object} store - Discourse store service
 * @param {Object} topic - The topic record to assign to each post
 * @param {Object} nodeData - Raw JSON from the server (with .children array)
 * @returns {{ post: Object, children: Array }}
 */
export default function processNode(store, topic, nodeData) {
  const post = store.createRecord("post", nodeData);
  post.topic = topic;
  const children = (nodeData.children || []).map((child) =>
    processNode(store, topic, child)
  );
  return { post, children };
}
