/**
  Supports Discourse's custom @mention syntax for calling out a user in a post.
  It will add a special class to them, and create a link if the user is found in a
  local map.
**/
Discourse.Dialect.inlineRegexp({
  start: '@',
  // NOTE: we really should be using SiteSettings here, but it loads later in process
  // also, if we do, we must ensure serverside version works as well
  matcher: /^(@[A-Za-z0-9][A-Za-z0-9_\.\-]{0,40}[A-Za-z0-9])/,
  wordBoundary: true,

  emitter: function(matches) {
    var username = matches[1],
        mentionLookup = this.dialect.options.mentionLookup;

    if (mentionLookup && mentionLookup(username.substr(1))) {
      return ['a', {'class': 'mention', href: Discourse.getURL("/users/") + username.substr(1).toLowerCase()}, username];
    } else {
      return ['span', {'class': 'mention'}, username];
    }
  }
});

// We have to prune @mentions that are within links.
Discourse.Dialect.on("parseNode", function(event) {
  var node = event.node,
      path = event.path;

  if (node[1] && node[1]["class"] === 'mention')  {
    var parent = path[path.length - 1];
    // If the parent is an 'a', remove it
    if (parent && parent[0] === 'a') {
      var username = node[2];
      node.length = 0;
      node[0] = "__RAW";
      node[1] = username;
    }
  }

});
