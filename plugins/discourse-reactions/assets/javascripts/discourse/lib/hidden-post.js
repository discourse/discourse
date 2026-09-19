// When a post is hidden and the viewer lacks permission to see
// it, the reaction affordances (counter and button) must be suppressed, otherwise
// interacting with them hits a 403 with no way to recover.
export function reactionsHiddenForUser(post) {
  return post.hidden && !post.can_see_hidden_post;
}
