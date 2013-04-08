/**
  This controller supports displaying custom pages.

  @class PagesController
  @extends Discourse.Controller
  @namespace Discourse
  @module Discourse
**/
Discourse.PagesController = Discourse.Controller.extend({
  content: null,

  loadPage: function(path) {
    var $preloaded, text,
      _this = this;
    this.set('content', null);
    // Load from <noscript> if we have it.
    $preloaded = $("noscript[data-path=\"" + path + "\"]");
    if ($preloaded.length) {
      text = $preloaded.text();
      text = text.match(/<!-- preload-content: -->((?:.|[\n\r])*)<!-- :preload-content -->/);
      text = text[1];
      return this.set('content', text);
    } else {
      return Discourse.ajax({
        url: Discourse.getURL("" + path + ".json"),
        success: function(result) {
          return _this.set('content', result);
        }
      });
    }
  }
});

Discourse.PagesController.reopenClass({
  pages: function() {
   routesFilter = function(pages) {
     var routes = []
     if (pages) {
       $(pages).each(function(page) {
         routes.pushObject(pages[page].route);
       });
     }
     return routes;
   }
   routes = routesFilter(PreloadStore.get('pages'));
   PreloadStore.remove('pages');
   return routes;
  }()
});


