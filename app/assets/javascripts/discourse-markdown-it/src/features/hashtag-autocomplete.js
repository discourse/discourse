// NOTE: For future maintainers, the hashtag lookup here does not take
// into account mixed contexts -- for instance, a chat quote inside a post
// or a post quote inside a chat message, so hashtagTypesInPriorityOrder may
// not provide an accurate lookup for hashtags without a ::type suffix in those
// cases if there are conflcting types of resources with the same slug.

function addHashtag(buffer, matches, state) {
  const options = state.md.options.discourse;
  const slug = matches[1];
  const hashtagLookup = options.hashtagLookup;

  // NOTE: The lookup function is only run when cooking
  // server-side, and will only return a single result based on the
  // slug lookup.
  const result =
    hashtagLookup &&
    hashtagLookup(slug, options.userId, options.hashtagTypesInPriorityOrder);

  // NOTE: When changing the HTML structure here, you must also change
  // it in the placeholder HTML code inside lib/hashtag-autocomplete, and vice-versa.
  let token;
  if (result) {
    token = new state.Token("link_open", "a", 1);

    // Data attributes here are used later on for things like quoting
    // HTML-to-markdown
    token.attrs = [
      ["class", "hashtag-cooked"],
      ["href", result.relative_url],
      ["data-type", result.type],
      ["data-slug", result.slug],
      ["data-id", result.id],
    ];

    if (result.style_type) {
      token.attrs.push(["data-style-type", result.style_type]);
    }

    if (result.style_type === "emoji" && result.emoji) {
      token.attrs.push(["data-emoji", result.emoji]);
    }

    if (result.style_type === "icon" && result.icon) {
      token.attrs.push(["data-icon", result.icon]);
    }

    // Most cases these will be the exact same, one standout is categories
    // which have a parent:child reference.
    if (result.slug !== result.ref) {
      token.attrs.push(["data-ref", result.ref]);
    }

    token.block = false;
    buffer.push(token);

    addIconPlaceholder(buffer, state);

    token = new state.Token("span_open", "span", 1);
    token.block = false;
    buffer.push(token);

    token = new state.Token("text", "", 0);
    token.content = result.text;
    buffer.push(token);

    buffer.push(new state.Token("span_close", "span", -1));

    buffer.push(new state.Token("link_close", "a", -1));
  } else {
    token = new state.Token("span_open", "span", 1);
    token.attrs = [["class", "hashtag-raw"]];
    buffer.push(token);

    token = new state.Token("span_open", "span", 1);
    token = new state.Token("text", "", 0);
    token.content = matches[0];
    buffer.push(token);
    token = new state.Token("span_close", "span", -1);

    token = new state.Token("span_close", "span", -1);
    buffer.push(token);
  }
}

// The svg icon is not baked into the HTML because we want
// to be able to use icon replacement via renderIcon, and
// because different hashtag types may render icons/CSS
// classes differently.
//
// Instead, the UI will dynamically replace these where hashtags
// are rendered, like within posts, using decorateCooked* APIs.
function addIconPlaceholder(buffer, state) {
  let token = new state.Token("span_open", "span", 1);
  token.block = false;
  token.attrs = [["class", "hashtag-icon-placeholder"]];
  buffer.push(token);

  token = new state.Token("svg_open", "svg", 1);
  token.block = false;
  token.attrs = [["class", `fa d-icon d-icon-square-full svg-icon svg-node`]];
  buffer.push(token);

  token = new state.Token("use_open", "use", 1);
  token.block = false;
  token.attrs = [["href", "#square-full"]];
  buffer.push(token);

  buffer.push(new state.Token("use_close", "use", -1));
  buffer.push(new state.Token("svg_close", "svg", -1));

  buffer.push(new state.Token("span_close", "span", -1));
}

export function setup(helper) {
  helper.registerPlugin((md) => {
    const rule = {
      matcher: /#([\u00C0-\u1FFF\u2C00-\uD7FF\w:-]{1,101})/,
      onMatch: addHashtag,
    };

    md.core.textPostProcess.ruler.push("hashtag-autocomplete", rule);
  });

  helper.allowList([
    "a.hashtag-cooked",
    "span.hashtag-raw",
    "span.hashtag-icon-placeholder",
    "svg[class=fa d-icon d-icon-square-full svg-icon svg-node]",
    "use[href=#square-full]",
    "a[data-type]",
    "a[data-slug]",
    "a[data-ref]",
    "a[data-id]",
    "a[data-style-type]",
    "a[data-icon]",
    "a[data-emoji]",
  ]);
}
