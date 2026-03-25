import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";

export const PAGE_SIZE = 20;

export function flattenAppreciation(item) {
  const title = item.post.topic_title;
  return {
    id: item.post.id,
    url: item.post.url,
    excerpt: item.post.excerpt,
    truncated: item.post.truncated,
    topic_id: item.post.topic_id,
    post_number: item.post.post_number,
    post_type: item.post.post_type,
    username: item.post.username,
    name: item.post.name,
    avatar_template: item.post.avatar_template,
    user_title: item.post.user_title,
    primary_group_name: item.post.primary_group_name,
    category: Category.findById(item.post.category_id),
    title,
    titleHtml: title && emojiUnescape(escapeExpression(title)),
    created_at: item.created_at,
    appreciation_type: item.type,
    acting_user: item.acting_user,
    metadata: item.metadata,
  };
}

// Groups likes on the same post into a single row with multiple acting users.
// Reactions and boosts are NOT grouped because they carry unique metadata
// (emoji value, boost text).
export function groupAppreciations(flatItems) {
  const result = [];
  const likesByPostId = new Map();

  for (const item of flatItems) {
    if (item.appreciation_type === "like") {
      const postId = item.id;
      if (likesByPostId.has(postId)) {
        const group = likesByPostId.get(postId);
        group.acting_users.push(item.acting_user);
        if (item.created_at > group.created_at) {
          group.created_at = item.created_at;
        }
      } else {
        const group = {
          ...item,
          acting_users: [item.acting_user],
        };
        likesByPostId.set(postId, group);
        result.push(group);
      }
    } else {
      result.push({ ...item, acting_users: [item.acting_user] });
    }
  }

  return result;
}
