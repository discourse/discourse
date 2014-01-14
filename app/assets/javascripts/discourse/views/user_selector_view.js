Discourse.UserSelector = Discourse.TextField.extend({

  didInsertElement: function() {
    var userSelectorView = this,
        selected = [];

    $(this.get('element')).val(this.get('usernames')).autocomplete({
      template: Discourse.UserSelector.templateFunction(),

      disabled: this.get('disabled'),
      single: this.get('single'),
      allowAny: this.get('allowAny'),

      dataSource: function(term) {
        var exclude = selected;
        if (userSelectorView.get('excludeCurrentUser')) {
          exclude = exclude.concat([Discourse.User.currentProp('username')]);
        }
        return Discourse.UserSearch.search({
          term: term,
          topicId: userSelectorView.get('topicId'),
          exclude: exclude,
          include_groups: userSelectorView.get('include_groups')
        });
      },

      transformComplete: function(v) {
        if (v.username) {
          return v.username;
        } else {
          return v.usernames;
        }
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

      reverseTransform: function(i) {
        return { username: i };
      }

    });
  }

});

Handlebars.registerHelper("showMax", function(context, block) {
  var maxLength = parseInt(block.hash.max) || 3;
  if (context.length > maxLength){
    return context.slice(0, maxLength).join(", ") + ", +" + (context.length - maxLength);
  } else {
    return context.join(", ");
  }
});

Discourse.UserSelector.reopenClass({
  // I really want to move this into a template file, but I need a handlebars template here, not an ember one
  templateFunction: function() {
      this.compiled = this.compiled || Handlebars.compile(
        "<div class='autocomplete'>" +
          "<ul>" +
          "{{#each options.users}}" +
            "<li>" +
                "<a href='#'>{{avatar this imageSize=\"tiny\"}} " +
                "<span class='username'>{{this.username}}</span> " +
                "<span class='name'>{{this.name}}</span></a>" +
            "</li>" +
          "{{/each}}" +
          "{{#if options.groups}}" +
            "{{#if options.users}}<hr>{{/if}}"+
              "{{#each options.groups}}" +
                "<li>" +
                  "<a href=''><i class='icon-group'></i>" +
                    "<span class='username'>{{this.name}}</span> " +
                    "<span class='name'>{{showMax this.usernames max=3}}</span>" +
                  "</a>" +
                "</li>" +
              "{{/each}}" +
            "{{/if}}" +
          "</ul>" +
        "</div>");
      return this.compiled;
    }
});

Discourse.View.registerHelper('userSelector', Discourse.UserSelector);
