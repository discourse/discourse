var compiled;

function templateFunction() {
  compiled = compiled || Handlebars.compile(
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
  return compiled;
}

export default Em.Component.extend({
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
        // TODO: Components should definitely not perform queries
        return Discourse.Group.findAll({search: term, ignore_automatic: true}).then(function(groups){
          if(!selectedGroups){
            return groups;
          }

          return groups.filter(function(group){
            return !selectedGroups.any(function(s){return s === group.name});
          });
        });
      },
      template: templateFunction()
    });
  }
});
