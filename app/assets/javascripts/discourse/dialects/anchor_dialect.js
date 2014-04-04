// prevent XSS
Discourse.Dialect.on('parseNode', function (event) {
  var node = event.node;

  if (node[0] === 'a') {
    var attributes = node[1];
    if (attributes["href"]) {
      if (!Discourse.Markdown.urlAllowed(attributes["href"])) {
        delete attributes["href"];
      }
    }
  }
});
