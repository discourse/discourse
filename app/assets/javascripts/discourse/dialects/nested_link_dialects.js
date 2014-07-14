Discourse.Dialect.on('parseNode', function (event) {
  var node = event.node,
      path = event.path;

  if (node[0] === 'a') {

    // It's invalid HTML to nest a link within another so strip it out.
    for (var i=0; i<path.length; i++) {
      if (path[i][0] === 'a') {
        var parent = path[path.length - 1],
            pos = parent.indexOf(node);

        // Just leave the link text
        if (pos !== -1) {
          parent[pos] = node[2];
        }
        return;
      }
    }
  }
});
