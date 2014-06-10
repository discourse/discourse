import TextField from 'discourse/views/text-field';

var compiled;
function templateFunction() {
  if (!compiled) {
    Handlebars.registerHelper("showMax", function(context, block) {
      var maxLength = parseInt(block.hash.max) || 3;
      if (context.length > maxLength){
        return context.slice(0, maxLength).join(", ") + ", +" + (context.length - maxLength);
      } else {
        return context.join(", ");
      }
    });

    compiled = Handlebars.compile(
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
  }
  return compiled;
}

var UserSelector = TextField.extend({

  didInsertElement: function() {
    var userSelectorView = this,
        selected = [];

    function excludedUsernames() {
      var exclude = selected;
      if (userSelectorView.get('excludeCurrentUser')) {
        exclude = exclude.concat([Discourse.User.currentProp('username')]);
      }
      return exclude;
    }

    $(this.get('element')).val(this.get('usernames')).autocomplete({
      template: templateFunction(),

      disabled: this.get('disabled'),
      single: this.get('single'),
      allowAny: this.get('allowAny'),

      dataSource: function(term) {
        return Discourse.UserSearch.search({
          term: term,
          topicId: userSelectorView.get('topicId'),
          exclude: excludedUsernames(),
          include_groups: userSelectorView.get('include_groups')
        });
      },

      transformComplete: function(v) {
        if (v.username) {
          return v.username;
        } else {
          var excludes = excludedUsernames();
          return v.usernames.filter(function(item){
                // include only, those not found in the exclude list
                return excludes.indexOf(item) === -1;
              });
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


UserSelector.reopenClass({ templateFunction: templateFunction });

export default UserSelector;
