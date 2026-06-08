export function registerPostInTopicPostStream(topic, post) {
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

export default function processNode(store, topic, nodeData) {
  const createdPost = store.createRecord("post", nodeData);
  const post = registerPostInTopicPostStream(topic, createdPost) || createdPost;

  if (post.topic !== topic) {
    post.topic = topic;
  }

  const children = (nodeData.children || []).map((child) =>
    processNode(store, topic, child)
  );
  return { post, children, _renderKey: nodeData._renderKey || post.id };
}
