/**
  Discourse does some server side rendering of HTML, such as the `cooked` contents of
  posts. The downside of this in an Ember app is the links will not go through the router.
  This jQuery code intercepts clicks on those links and routes them properly.
**/
export default {
  name: "click-interceptor",
  initialize: function() {
    $('#main').on('click.discourse', 'a', function(e) {
      if (e.isDefaultPrevented() || e.shiftKey || e.metaKey || e.ctrlKey) { return; }

      var $currentTarget = $(e.currentTarget),
          href = $currentTarget.attr('href');

      if (!href ||
          href === '#' ||
          $currentTarget.attr('target') ||
          $currentTarget.data('ember-action') ||
          $currentTarget.data('auto-route') ||
          $currentTarget.data('share-url') ||
          $currentTarget.data('user-card') ||
          $currentTarget.hasClass('mention') ||
          $currentTarget.hasClass('ember-view') ||
          $currentTarget.hasClass('lightbox') ||
          href.indexOf("mailto:") === 0 ||
          (href.match(/^http[s]?:\/\//i) && !href.match(new RegExp("^http:\\/\\/" + window.location.hostname, "i")))) {
         return;
      }

      e.preventDefault();
      Discourse.URL.routeTo(href);
      return false;
    });
  }
};
