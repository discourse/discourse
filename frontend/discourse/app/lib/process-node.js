export default function processNode(store, topic, nodeData) {
  const createdPost = store.createRecord("post", nodeData);
  const post = topic.postStream?.storePost(createdPost) || createdPost;

  if (post.topic !== topic) {
    post.topic = topic;
  }

  const children = (nodeData.children || []).map((child) =>
    processNode(store, topic, child)
  );
  return { post, children };
}
