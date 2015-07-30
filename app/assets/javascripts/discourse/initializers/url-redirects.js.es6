export default {
  name: 'url-redirects',
  initialize: function() {

    // URL rewrites (usually due to refactoring)
    Discourse.URL.rewrite(/^\/category\//, "/c/");
    Discourse.URL.rewrite(/^\/group\//, "/groups/");
    Discourse.URL.rewrite(/\/private-messages\/$/, "/messages/");
    Discourse.URL.rewrite(/^\/users\/([^\/]+)\/?$/, "/users/$1/activity");
  }
};
