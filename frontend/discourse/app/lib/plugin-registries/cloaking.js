// Post ids that must stay rendered whatever the scroll position. The topic id
// lets the tracker clear the set when the topic changes.
export const cloakingPrevented = { topicId: null, posts: new Set() };

export function preventCloaking(postId, prevent = true) {
  if (prevent) {
    cloakingPrevented.posts.add(postId);
  } else {
    cloakingPrevented.posts.delete(postId);
  }
}
