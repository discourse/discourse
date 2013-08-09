Discourse.UserSelector = Discourse.TextField.extend({

  didInsertElement: function(){

    var userSelectorView = this;
    var selected = [];
    var transformTemplate = Handlebars.compile("{{avatar this imageSize=\"tiny\"}} {{this.username}}");

    $(this.get('element')).val(this.get('usernames')).autocomplete({
      template: Discourse.UserSelector.templateFunction(),

      disabled: this.get('disabled'),
      single: this.get('single'),
      allowAny: this.get('allowAny'),
      dataSource: function(term) {
        var exclude = selected;
        if (userSelectorView.get('excludeCurrentUser')){
          exclude = exclude.concat([Discourse.User.currentProp('username')]);
        }
        return Discourse.UserSearch.search({
          term: term,
          topicId: userSelectorView.get('topicId'),
          exclude: exclude
        });
      },

      onChangeItems: function(items) {
        items = _.map(items, function(i) {
          if (i.username) {
            return i.username;
          } else {
            return i;
          }
        });
        userSelectorView.set('usernames', items.join(","));
        selected = items;
      },

      transformComplete: transformTemplate,

      reverseTransform: function(i) {
        return { username: i };
      }

    });
  }

});


Discourse.UserSelector.reopenClass({
  // I really want to move this into a template file, but I need a handlebars template here, not an ember one
  templateFunction: function(){
      this.compiled = this.compiled || Handlebars.compile("<div class='autocomplete'>" +
                                    "<ul>" +
                                    "{{#each options}}" +
                                      "<li>" +
                                          "<a href='#'>{{avatar this imageSize=\"tiny\"}} " +
                                          "<span class='username'>{{this.username}}</span> " +
                                          "<span class='name'>{{this.name}}</span></a>" +
                                      "</li>" +
                                      "{{/each}}" +
                                    "</ul>" +
                                  "</div>");
      return this.compiled;
    }
});

Discourse.View.registerHelper('userSelector', Discourse.UserSelector);
