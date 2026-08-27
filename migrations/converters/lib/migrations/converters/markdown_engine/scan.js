/* eslint-disable no-undef, no-unused-vars */
// Reads the parsed token tree into compact per-post data: per inline block,
// the construct values the engine recognized plus the block's line map, and
// separately the line maps of code/html/quote blocks. Only this compact data
// crosses the V8 boundary, never the token tree itself.

function __scanCountOccurrences(haystack, needle) {
  // An empty needle would match at every position without ever advancing
  // the cursor (indexOf("") is always the current index).
  if (needle.length === 0) {
    return 0;
  }
  let count = 0;
  let index = haystack.indexOf(needle);
  while (index !== -1) {
    count += 1;
    index = haystack.indexOf(needle, index + needle.length);
  }
  return count;
}

// How often the link's destination also appears in its label text — a
// `[URL](same URL)` self-link writes the value twice in the raw, so count
// certification must expect both occurrences. The schemeless reading covers
// a label spelling the bare domain of a linkified destination. Empty-
// destination links (`[text]()`, `[](https://)` whose schemeless reading is
// empty) can never be self-links.
function __scanLabelHits(label, href) {
  if (href.length === 0) {
    return 0;
  }
  if (label.includes(href)) {
    return __scanCountOccurrences(label, href);
  }
  const bare = href.replace(/^https?:\/\//, "");
  if (bare.length > 0 && bare !== href && label.includes(bare)) {
    return __scanCountOccurrences(label, bare);
  }
  return 0;
}

function __scanWalk(children, block) {
  if (!children) {
    return;
  }
  const linkStack = [];
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
      // and stores the original in data-orig-*; the original is the
      // construct.
      const href = child.attrGet("data-orig-href") || child.attrGet("href");
      if (hashtagType !== null) {
        // For a hashtag the slug and type are the construct — the href shape
        // depends on lookup internals that scanning replaces.
        block.hashtags.push({
          type: hashtagType,
          slug: child.attrGet("data-ref") || child.attrGet("data-slug") || "",
        });
        linkStack.push(null);
      } else if (href !== null && href[0] !== "#") {
        // Fragment-only hrefs are intra-post anchors — some synthesized from
        // headings, none in need of remapping — so they are not constructs.
        // A linkified or autolinked URL is its own label but exists once in
        // the raw, so only an explicit `[label](dest)` link can contribute
        // label occurrences.
        const explicit = child.markup !== "linkify" && child.info !== "auto";
        linkStack.push({ href, label: "", explicit });
      } else {
        linkStack.push(null);
      }
    } else if (child.type === "link_close") {
      const open = linkStack.pop();
      if (open) {
        block.links.push({
          href: open.href,
          labelHits: open.explicit ? __scanLabelHits(open.label, open.href) : 0,
        });
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
    } else {
      if (child.type === "text" && linkStack.length > 0) {
        const open = linkStack[linkStack.length - 1];
        if (open) {
          open.label += child.content;
        }
      }
      if (child.children) {
        __scanWalk(child.children, block);
      }
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
