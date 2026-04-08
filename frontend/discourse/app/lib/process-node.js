export default function processNode(store, topic, nodeData) {
  const post = store.createRecord("post", nodeData);
  post.topic = topic;
  const children = (nodeData.children || []).map((child) =>
    processNode(store, topic, child)
  );
  return { post, children };
}
