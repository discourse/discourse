function addHashtag(buffer, matches, state) {
  const options = state.md.options.discourse;
  const slug = matches[1];
  const categoryHashtagLookup = options.categoryHashtagLookup;
  const result = categoryHashtagLookup && categoryHashtagLookup(slug);

  let token;

  if (result) {
    token = new state.Token("link_open", "a", 1);
    token.attrs = [["class", "hashtag"], ["href", result[0]]];
    token.block = false;
    buffer.push(token);

    token = new state.Token("text", "", 0);
    token.content = "#";
    buffer.push(token);

    token = new state.Token("span_open", "span", 1);
    token.block = false;
    buffer.push(token);

    token = new state.Token("text", "", 0);
    token.content = result[1];
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
  helper.registerPlugin(md => {
    const rule = {
      matcher: /#([\w-:]{1,101})/,
      onMatch: addHashtag
    };

    md.core.textPostProcess.ruler.push("category-hashtag", rule);
  });
}
