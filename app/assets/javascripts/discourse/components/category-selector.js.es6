import { categoryBadgeHTML } from 'discourse/helpers/category-link';
import Category from 'discourse/models/category';
import { on, observes } from 'ember-addons/ember-computed-decorators';
import { getOwner } from 'discourse-common/lib/get-owner';

export default Ember.Component.extend({
  @observes('categories')
  _update() {
    if (this.get('canReceiveUpdates') === 'true')
      this._initializeAutocomplete({updateData: true});
  },

  @on('didInsertElement')
  _initializeAutocomplete(opts) {
    const self = this,
          template = getOwner(this).lookup('template:category-selector-autocomplete.raw'),
          regexp = new RegExp(`href=['\"]${Discourse.getURL('/c/')}([^'\"]+)`);

    this.$('input').autocomplete({
      items: this.get('categories'),
      single: this.get('single'),
      allowAny: false,
      updateData: (opts && opts.updateData) ? opts.updateData : false,
      dataSource(term) {
        return Category.list().filter(category => {
          const regex = new RegExp(term, 'i');
          return category.get('name').match(regex) &&
            !_.contains(self.get('blacklist') || [], category) &&
            !_.contains(self.get('categories'), category) ;
        });
      },
      onChangeItems(items) {
        const categories = _.map(items, link => {
          const slug = link.match(regexp)[1];
          return Category.findSingleBySlug(slug);
        });
        Em.run.next(() => {
          let existingCategory = _.isArray(self.get('categories')) ? self.get('categories') : [self.get('categories')];
          const result = _.intersection(existingCategory.map(itm => itm.id), categories.map(itm => itm.id));
          if (result.length !== categories.length || existingCategory.length !== categories.length)
            self.set('categories', categories);
        });
      },
      template,
      transformComplete(category) {
        return categoryBadgeHTML(category, {allowUncategorized: true});
      }
    });
  }
});
