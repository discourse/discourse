import { categoryBadgeHTML } from 'discourse/helpers/category-link';

export default Ember.Component.extend({

  _initializeAutocomplete: function() {
    const self = this,
          template = this.container.lookup('template:category-group-autocomplete.raw'),
          regexp = new RegExp("href=['\"]" + Discourse.getURL('/c/') + "([^'\"]+)");

    this.$('input').autocomplete({
      items: this.get('categories'),
      single: false,
      allowAny: false,
      dataSource(term){
        return Discourse.Category.list().filter(function(category){
          const regex = new RegExp(term, "i");
          return category.get("name").match(regex) &&
            !_.contains(self.get('blacklist') || [], category) &&
            !_.contains(self.get('categories'), category) ;
        });
      },
      onChangeItems(items) {
        const categories = _.map(items, function(link) {
          const slug = link.match(regexp)[1];
          return Discourse.Category.findSingleBySlug(slug);
        });
        Em.run.next(() => self.set("categories", categories));
      },
      template,
      transformComplete(category) {
        return categoryBadgeHTML(category, {allowUncategorized: true});
      }
    });
  }.on('didInsertElement')

});
