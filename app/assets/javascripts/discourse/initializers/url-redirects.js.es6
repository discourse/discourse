export default {
  name: 'url-redirects',
  initialize: function() {

    // URL rewrites (usually due to refactoring)
    Discourse.URL.rewrite(/^\/category\//, "/c/");
    Discourse.URL.rewrite(/^\/group\//, "/groups/");
  }
};
