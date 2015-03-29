Discourse.StaticPage = Em.Object.extend();

Discourse.StaticPage.reopenClass({
  find: function(path) {
    return new Em.RSVP.Promise(function(resolve) {
      // Models shouldn't really be doing Ajax request, but this is a huge speed boost if we
      // preload content.
      var $preloaded = $("noscript[data-path=\"/" + path + "\"]");
      if ($preloaded.length) {
        var text = $preloaded.text();
        text = text.match(/<!-- preload-content: -->((?:.|[\n\r])*)<!-- :preload-content -->/)[1];
        resolve(Discourse.StaticPage.create({path: path, html: text}));
      } else {
        Discourse.ajax(path + ".html", {dataType: 'html'}).then(function (result) {
          resolve(Discourse.StaticPage.create({path: path, html: result}));
        });
      }
    });
  }
});
