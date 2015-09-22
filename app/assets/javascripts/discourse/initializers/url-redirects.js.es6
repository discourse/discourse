import DiscourseURL from 'discourse/lib/url';

export default {
  name: 'url-redirects',
  initialize: function() {

    // URL rewrites (usually due to refactoring)
    DiscourseURL.rewrite(/^\/category\//, "/c/");
    DiscourseURL.rewrite(/^\/group\//, "/groups/");
    DiscourseURL.rewrite(/\/private-messages\/$/, "/messages/");
    DiscourseURL.rewrite(/^\/users\/([^\/]+)\/?$/, "/users/$1/activity");
  }
};
