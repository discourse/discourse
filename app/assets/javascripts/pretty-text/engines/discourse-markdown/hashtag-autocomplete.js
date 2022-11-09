function addHashtag(buffer, matches, state) {
  const options = state.md.options.discourse;
  const slug = matches[1];
  const hashtagLookup = options.hashtagLookup;
  const result =
    hashtagLookup &&
    hashtagLookup(
      slug,
      options.currentUser,
      options.hashtagTypesInPriorityOrder
    );

  let token;
  if (result) {
    token = new state.Token("link_open", "a", 1);
    token.attrs = [
      ["class", "hashtag-cooked"],
      ["href", result.url],
    ];
    token.block = false;
    buffer.push(token);

    token = new state.Token("span_open", "span", 1);
    token.block = false;
    buffer.push(token);

    token = new state.Token("svg_open", "svg", 1);
    token.block = false;
    token.attrs = [
      ["class", `fa d-icon d-icon-${result.icon} svg-icon svg-node`],
    ];
    buffer.push(token);

    token = new state.Token("use_open", "use", 1);
    token.block = false;
    token.attrs = [["href", `#${result.icon}`]];
    buffer.push(token);

    buffer.push(new state.Token("use_close", "use", -1));

    buffer.push(new state.Token("svg_close", "svg", -1));

    token = new state.Token("text", "", 0);
    token.content = result.text;
    buffer.push(token);

    buffer.push(new state.Token("span_close", "span", -1));

    buffer.push(new state.Token("link_close", "a", -1));
  } else {
    token = new state.Token("span_open", "span", 1);
    token.attrs = [["class", "hashtag"]];
    buffer.push(token);

    token = new state.Token("text", "", 0);
    token.content = matches[0];
    buffer.push(token);

    token = new state.Token("span_close", "span", -1);
    buffer.push(token);
  }
}

export function setup(helper) {
  helper.allowList([
    "a.hashtag-cooked",
    "svg[class=fa d-icon d-icon-folder svg-icon svg-node]",
    "use[href=#folder]",
    "svg[class=fa d-icon d-icon-tag svg-icon svg-node]",
    "use[href=#tag]",
    "svg[class=fa d-icon d-icon-comment svg-icon svg-node]",
    "use[href=#comment]",
  ]);

  helper.registerPlugin((md) => {
    if (
      md.options.discourse.limitedSiteSettings
        .enableExperimentalHashtagAutocomplete
    ) {
      const rule = {
        matcher: /#([\u00C0-\u1FFF\u2C00-\uD7FF\w:-]{1,101})/,
        onMatch: addHashtag,
      };

      md.core.textPostProcess.ruler.push("hashtag-autocomplete", rule);
    }
  });
}
