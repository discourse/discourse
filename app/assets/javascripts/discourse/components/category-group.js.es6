import { categoryBadgeHTML } from 'discourse/helpers/category-link';

export default Ember.Component.extend({

  _initializeAutocomplete: function(){
    var self = this;
    var template = this.container.lookup('template:category-group-autocomplete.raw');

    this.$('input').autocomplete({
      items: this.get('categories'),
      single: false,
      allowAny: false,
      dataSource: function(term){
        return Discourse.Category.list().filter(function(category){
          var regex = new RegExp(term, "i");
          return category.get("name").match(regex) &&
            !_.contains(self.get('blacklist') || [], category) &&
            !_.contains(self.get('categories'), category) ;
        });
      },
      onChangeItems: function(items) {
        var categories = _.map(items, function(link) {
          var slug = link.match(/href=['"]\/c\/([^'"]+)/)[1];
          return Discourse.Category.findSingleBySlug(slug);
        });
        self.set("categories", categories);
      },
      template: template,
      transformComplete: function(category) {
        return categoryBadgeHTML(category, {allowUncategorized: true});
      }
    });
  }.on('didInsertElement')

});
