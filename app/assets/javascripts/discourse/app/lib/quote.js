import { prioritizeNameFallback } from "discourse/lib/settings";
import { helperContext } from "discourse-common/lib/helpers";

export const QUOTE_REGEXP = /\[quote=([^\]]*)\]((?:[\s\S](?!\[quote=[^\]]*\]))*?)\[\/quote\]/im;

// Build the BBCode quote around the selected text
export function buildQuote(post, contents, opts = {}) {
  if (!post || !contents) {
    return "";
  }

  const name = prioritizeNameFallback(
    post.name,
    opts.username || post.username
  );

  const params = [
    name,
    `post:${opts.post || post.post_number}`,
    `topic:${opts.topic || post.topic_id}`,
  ];

  if (opts.full) {
    params.push("full:true");
  }
  if (
    helperContext().siteSettings.display_name_on_posts &&
    !helperContext().siteSettings.prioritize_username_in_ux
  ) {
    params.push(`username:${opts.username || post.username}`);
  }

  return `[quote="${params.join(", ")}"]\n${contents.trim()}\n[/quote]\n\n`;
}
