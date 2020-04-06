export const QUOTE_REGEXP = /\[quote=([^\]]*)\]((?:[\s\S](?!\[quote=[^\]]*\]))*?)\[\/quote\]/im;

// Build the BBCode quote around the selected text
export function buildQuote(post, contents, opts = {}) {
  if (!post || !contents) {
    return "";
  }

  const params = [
    opts.username || post.username,
    `post:${opts.post || post.post_number}`,
    `topic:${opts.topic || post.topic_id}`
  ];

  if (opts.full) params.push("full:true");

  return `[quote="${params.join(", ")}"]\n${contents.trim()}\n[/quote]\n\n`;
}
