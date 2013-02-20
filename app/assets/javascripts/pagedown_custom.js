(function() {

  window.PagedownCustom = {
    insertButtons: [
      {
        id: 'wmd-quote-post',
        description: 'Quote Post',
        execute: function() {
          /* AWFUL but I can't figure out how to call a controller method from outside
          */

          /* my app?
          */
          return Discourse.__container__.lookup('controller:composer').importQuote();
        }
      }
    ]
  };

}).call(this);
