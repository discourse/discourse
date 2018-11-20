function addMention(buffer, matches, state) {
  let username = matches[1] || matches[2];
  let { getURL, mentionLookup, formatUsername } = state.md.options.discourse;

  let type = mentionLookup && mentionLookup(username);

  let tag = "a";
  let className = "mention";
  let href = null;

  if (type === "user") {
    href = getURL("/u/") + username.toLowerCase();
  } else if (type === "group") {
    href = getURL("/groups/") + username;
    className = "mention-group";
  } else {
    tag = "span";
  }

  let token = new state.Token("mention_open", tag, 1);
  token.attrs = [["class", className]];
  if (href) {
    token.attrs.push(["href", href]);
  }

  buffer.push(token);
  if (formatUsername) {
    username = formatUsername(username);
  }

  token = new state.Token("text", "", 0);
  token.content = "@" + username;

  buffer.push(token);

  token = new state.Token("mention_close", tag, -1);
  buffer.push(token);
}

export function setup(helper) {
  helper.registerOptions((opts, siteSettings) => {
    opts.features.mentions = !!siteSettings.enable_mentions;
  });

  helper.registerPlugin(md => {
    const rule = {
      matcher: /@(\w[\w.-]{0,58}\w)|@(\w)/,
      onMatch: addMention
    };

    md.core.textPostProcess.ruler.push("mentions", rule);
  });
}
