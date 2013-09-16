/*global Markdown:true*/

window.PagedownCustom = {
  insertButtons: [
    {
      id: 'wmd-quote-post',
      description: I18n.t("composer.quote_post_title"),
      execute: function() {
        // AWFUL but I can't figure out how to call a controller method from outside our app
        return Discourse.__container__.lookup('controller:composer').send('importQuote');
      }
    }
  ]
};
