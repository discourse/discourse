import { emojiUnescape } from "discourse/lib/text";
import { escapeExpression } from "discourse/lib/utilities";

export const PAGE_SIZE = 20;

export function flattenBoost(boost) {
  const title = boost.post.topic_title;
  return {
    boost_id: boost.id,
    boost_cooked: boost.cooked,
    boost_raw: boost.raw,
    booster: {
      username: boost.user.username,
      name: boost.user.name,
      avatar_template: boost.user.avatar_template,
    },
    id: boost.post.id,
    user_id: boost.post.user_id,
    username: boost.post.username,
    name: boost.post.name,
    avatar_template: boost.post.avatar_template,
    excerpt: emojiUnescape(escapeExpression(boost.post.excerpt)),
    topic_id: boost.post.topic_id,
    url: boost.post.url,
    title,
    titleHtml: title && emojiUnescape(escapeExpression(title)),
    created_at: boost.created_at,
  };
}
