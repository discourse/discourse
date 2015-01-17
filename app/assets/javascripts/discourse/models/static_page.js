Discourse.StaticPage = Em.Object.extend();

Discourse.StaticPage.reopenClass({
  find: function(path) {
    // Models shouldn't really be doing Ajax request, but this is a huge speed boost if we
    // preload content.
    if (PreloadStore.get('static/' + path)) {
      return PreloadStore.getAndRemove('static/' + path).then(function(htmlString) {
        return Discourse.StaticPage.create({path: path, html: htmlString});
      });
    } else {
      return Discourse.ajax(path + ".html", {dataType: 'html'}).then(function (result) {
        return Discourse.StaticPage.create({path: path, html: result});
      });
    }
  }
});
