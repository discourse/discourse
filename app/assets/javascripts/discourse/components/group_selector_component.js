Discourse.GroupSelectorComponent = Em.Component.extend({
  placeholder: function(){
    return I18n.t(this.get("placeholderKey"));
  }.property("placeholderKey"),

  didInsertElement: function() {
    var self = this;
    var selectedGroups;

    self.$('input').autocomplete({
      allowAny: false,
      onChangeItems: function(items){
        selectedGroups = items;
        self.set("groupNames", items.join(","));
      },
      transformComplete: function(g) {
        return g.name;
      },
      dataSource: function(term) {
        return Discourse.Group.findAll({search: term, ignore_automatic: true}).then(function(groups){
          if(!selectedGroups){
            return groups;
          }

          return groups.filter(function(group){
            return !selectedGroups.any(function(s){return s === group.name});
          });
        });
      },
      template: Discourse.GroupSelectorComponent.templateFunction()
    });
  }
});

// TODO autocomplete should become an ember component, then we don't need this
Discourse.GroupSelectorComponent.reopenClass({
  templateFunction: function() {
      this.compiled = this.compiled || Handlebars.compile(
        "<div class='autocomplete'>" +
          "<ul>" +
          "{{#each options}}" +
            "<li>" +
                "<a href=''>{{this.name}}</a>" +
            "</li>" +
          "{{/each}}" +
          "</ul>" +
          "</div>"
      );

      return this.compiled;
  }
});
