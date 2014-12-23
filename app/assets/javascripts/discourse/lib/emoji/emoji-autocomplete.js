// TODO: Make this a proper ES6 import
var ComposerView = require('discourse/views/composer').default;

ComposerView.on("initWmdEditor", function(){
  if (!Discourse.SiteSettings.enable_emoji) { return; }

  var template = Handlebars.compile(
    "<div class='autocomplete'>" +
      "<ul>" +
        "{{#each options}}" +
            "<li>" +
              "<a href='#'><img src='{{src}}' class='emoji'> {{code}}</a>" +
            "</li>" +
        "{{/each}}" +
      "</ul>" +
    "</div>"
  );

  $('#wmd-input').autocomplete({
    template: template,
    key: ":",
    transformComplete: function(v){ return v.code + ":"; },
    dataSource: function(term){
      return new Ember.RSVP.Promise(function(resolve) {
        var full = ":" + term;
        term = term.toLowerCase();

        if (term === "") {
          return resolve(["smile", "smiley", "wink", "sunny", "blush"]);
        }

        if (Discourse.Emoji.translations[full]) {
          return resolve([Discourse.Emoji.translations[full]]);
        }

        var options = Discourse.Emoji.search(term, {maxResults: 5});

        return resolve(options);
      }).then(function(list) {
        return list.map(function(i) {
          return {code: i, src: Discourse.Emoji.urlFor(i)};
        });
      });
    }
  });
});
