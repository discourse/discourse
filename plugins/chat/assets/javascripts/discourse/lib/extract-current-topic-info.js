import { getOwner } from "@ember/application";

export function extractCurrentTopicInfo(context) {
  const topic = getOwner(context).lookup("controller:topic")?.model;

  if (!topic) {
    return;
  }

  const info = { context_topic_id: topic.id };
  const currentPostNumber = topic.currentPost;
  const posts = topic.postStream.posts;

  const currentPost = posts.find(
    (post) => post.post_number === currentPostNumber
  );
  const previousPost = posts.findLast(
    (post) =>
      !post.hidden && !post.deleted_at && post.post_number < currentPostNumber
  );
  const nextPost = posts.find(
    (post) =>
      !post.hidden && !post.deleted_at && post.post_number > currentPostNumber
  );

  info.context_post_ids = [
    previousPost?.id,
    currentPost?.id,
    nextPost?.id,
  ].filter(Boolean);

  return info;
}
