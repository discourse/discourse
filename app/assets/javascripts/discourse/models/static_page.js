Discourse.StaticPage = Em.Object.extend();

Discourse.StaticPage.reopenClass({
  find: function(path) {
    return new Em.RSVP.Promise(function(resolve) {
      // Models shouldn't really be doing Ajax request, but this is a huge speed boost if we
      // preload content.
      Discourse.ajax(path + ".html", {dataType: 'html'}).then(function (result) {
        resolve(Discourse.StaticPage.create({path: path, html: result}));
      });
    });
  }
});
