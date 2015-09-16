export default Ember.Component.extend({
  placeholder: function(){
    return I18n.t(this.get("placeholderKey"));
  }.property("placeholderKey"),

  _initializeAutocomplete: function() {
    var self = this;
    var selectedGroups;

    var template = this.container.lookup('template:group-selector-autocomplete.raw');
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
        return self.get("groupFinder")(term).then(function(groups){

          if(!selectedGroups){
            return groups;
          }

          return groups.filter(function(group){
            return !selectedGroups.any(function(s){return s === group.name;});
          });
        });
      },
      template: template
    });
  }.on('didInsertElement')
});
