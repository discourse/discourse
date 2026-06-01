export default function processNode(store, topic, nodeData) {
  const post = topic.postStream.storePost(store.createRecord("post", nodeData));
  const children = (nodeData.children || []).map((child) =>
    processNode(store, topic, child)
  );
  return { post, children };
}
