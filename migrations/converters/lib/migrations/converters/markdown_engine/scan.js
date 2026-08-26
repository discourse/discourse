/* eslint-disable no-undef, no-unused-vars */
// The token walk: per inline block, the construct values the engine
// recognized plus the block's line map; separately, the line maps of
// code/html/quote blocks. Compact data only — the token tree never crosses
// the V8 boundary. Ported from the benchmark walk that was debugged against a
// real corpus (see migrations/docs/markdown-engine-context.md).

function __scanWalk(children, block) {
  if (!children) {
    return;
  }
  for (let i = 0; i < children.length; i++) {
    const child = children[i];
    if (child.type === "mention_open") {
      const next = children[i + 1];
      if (next && next.type === "text") {
        block.mentions.push(next.content);
      }
    } else if (child.type === "link_open") {
      const hashtagType = child.attrGet("data-type");
      // The upload protocol rewrites unresolved short URLs into a placeholder
      // and stashes the original in data-orig-*; the original is the
      // construct.
      const href = child.attrGet("data-orig-href") || child.attrGet("href");
      if (hashtagType !== null) {
        // For a hashtag the slug and type are the construct — the href shape
        // depends on lookup internals that scanning replaces.
        block.hashtags.push({
          type: hashtagType,
          slug: child.attrGet("data-ref") || child.attrGet("data-slug") || "",
        });
      } else if (href !== null && href[0] !== "#") {
        // Fragment-only hrefs are intra-post anchors — some synthesized from
        // headings, none in need of remapping — so they are not constructs.
        block.links.push(href);
      }
    } else if (child.type === "image") {
      const src = child.attrGet("data-orig-src") || child.attrGet("src");
      if (src !== null) {
        block.images.push(src);
      }
      __scanWalk(child.children, block);
    } else if (child.type === "emoji") {
      const title = child.attrGet("title");
      if (title !== null) {
        block.emojis.push(title.replace(/^:|:$/g, ""));
      }
    } else if (child.type === "code_inline") {
      block.code += 1;
    } else if (child.children) {
      __scanWalk(child.children, block);
    }
  }
}

function __scanOne(post) {
  const tokens = __pt.parse(post.raw);
  const blocks = [];
  const blockTokens = [];
  for (const token of tokens) {
    if (token.type === "inline") {
      const block = {
        map: token.map,
        mentions: [],
        hashtags: [],
        links: [],
        images: [],
        emojis: [],
        code: 0,
      };
      __scanWalk(token.children, block);
      if (
        block.mentions.length ||
        block.hashtags.length ||
        block.links.length ||
        block.images.length ||
        block.emojis.length ||
        block.code > 0
      ) {
        blocks.push(block);
      }
    } else if (
      token.map &&
      (token.type === "fence" ||
        token.type === "code_block" ||
        token.type === "html_block" ||
        // A quote's outer aside token carries no map; the inner blockquote
        // bbcode token does, so any mapped bbcode block is recorded with its
        // tag for downstream disambiguation.
        token.type === "bbcode_open")
    ) {
      blockTokens.push({ type: token.type, tag: token.tag, map: token.map });
    }
  }
  return { id: post.id, blocks, blockTokens };
}

function __scanPosts(posts) {
  return posts.map(__scanOne);
}
