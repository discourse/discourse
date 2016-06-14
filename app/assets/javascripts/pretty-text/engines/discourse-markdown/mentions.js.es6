/**
  Supports our custom @mention syntax for calling out a user in a post.
  It will add a special class to them, and create a link if the user is found in a
  local map.
**/
export function setup(helper) {

  // We have to prune @mentions that are within links.
  helper.onParseNode(event => {
    const node = event.node,
    path = event.path;

    if (node[1] && node[1]["class"] === 'mention')  {
      const parent = path[path.length - 1];

      // If the parent is an 'a', remove it
      if (parent && parent[0] === 'a') {
        const name = node[2];
        node.length = 0;
        node[0] = "__RAW";
        node[1] = name;
      }
    }
  });

  helper.inlineRegexp({
    start: '@',
    // NOTE: since we can't use SiteSettings here (they loads later in process)
    // we are being less strict to account for more cases than allowed
    matcher: /^@(\w[\w.-]{0,59})\b/i,
    wordBoundary: true,

    emitter(matches) {
      const mention = matches[0].trim();
      const name = matches[1];
      const opts = helper.getOptions();
      const mentionLookup = opts.mentionLookup;

      const type = mentionLookup && mentionLookup(name);
      if (type === "user") {
        return ['a', {'class': 'mention', href: opts.getURL("/users/") + name.toLowerCase()}, mention];
      } else if (type === "group") {
        return ['a', {'class': 'mention-group', href: opts.getURL("/groups/") + name}, mention];
      } else {
        return ['span', {'class': 'mention'}, mention];
      }
    }
  });
}
