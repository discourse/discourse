import { ajax } from "discourse/lib/ajax";
const StaticPage = Ember.Object.extend();

StaticPage.reopenClass({
  find(path) {
    return new Ember.RSVP.Promise(resolve => {
      // Models shouldn't really be doing Ajax request, but this is a huge speed boost if we
      // preload content.
      const $preloaded = $('noscript[data-path="/' + path + '"]');
      if ($preloaded.length) {
        let text = $preloaded.text();
        text = text.match(
          /<!-- preload-content: -->((?:.|[\n\r])*)<!-- :preload-content -->/
        )[1];
        resolve(StaticPage.create({ path: path, html: text }));
      } else {
        ajax(path + ".html", { dataType: "html" }).then(function(result) {
          resolve(StaticPage.create({ path: path, html: result }));
        });
      }
    });
  }
});

export default StaticPage;
