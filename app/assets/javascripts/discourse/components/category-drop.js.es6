import { setting } from 'discourse/lib/computed';
import computed from 'ember-addons/ember-computed-decorators';

var get = Ember.get;

export default Ember.Component.extend({
  classNameBindings: ['category::no-category', 'categories:has-drop', 'categoryStyle'],
  categoryStyle: setting('category_style'),
  expanded: false,

  tagName: 'li',

  @computed('expanded')
  expandIcon(expanded) {
    return expanded ? 'd-drop-expanded' : 'd-drop-collapsed';
  },

  allCategoriesUrl: function() {
    if (this.get('subCategory')) {
      return this.get('parentCategory.url') || "/";
    } else {
      return "/";
    }
  }.property('parentCategory.url', 'subCategory'),

  noCategoriesUrl: function() {
    return this.get('parentCategory.url') + "/none";
  }.property('parentCategory.url'),

  allCategoriesLabel: function() {
    if (this.get('subCategory')) {
      return I18n.t('categories.all_subcategories', {categoryName: this.get('parentCategory.name')});
    }
    return I18n.t('categories.all');
  }.property('category'),

  dropdownButtonClass: function() {
    let result = 'dropdown-header category-dropdown-button';
    if (Em.isNone(this.get('category'))) {
      result += ' home';
    }
    return result;
  }.property('category'),

  categoryColor: function() {
    var category = this.get('category');

    if (category) {
      var color = get(category, 'color');

      if (color) {
        var style = "";
        if (color) { style += "background-color: #" + color + ";"; }
        return style.htmlSafe();
      }
    }

    return "background-color: #eee;".htmlSafe();
  }.property('category'),

  badgeStyle: function() {
    let category = this.get('category');

    const categoryStyle = this.siteSettings.category_style;
    if (categoryStyle === 'bullet') {
      return;
    }

    if (category) {
      let color = get(category, 'color');
      let textColor = get(category, 'text_color');

      if (color || textColor) {
        let style = "";
        if (color) {
          if (categoryStyle === "bar") {
            style += `border-color: #${color};`;
          } else if (categoryStyle === "box") {
            style += `background-color: #${color};`;
            if (textColor) { style += "color: #" + textColor + "; "; }
          }
        }

        return style.htmlSafe();
      }
    }

    if (categoryStyle === 'box') {
      return "background-color: #eee; color: #333".htmlSafe();
    }
  }.property('category'),

  clickEventName: function() {
    return "click.category-drop-" + (this.get('category.id') || "all");
  }.property('category.id'),

  actions: {
    expand: function() {
      var self = this;

      if(!this.get('renderCategories')){
        this.set('renderCategories',true);
        Em.run.next(function(){
          self.send('expand');
        });
        return;
      }

      if (this.get('expanded')) {
        this.close();
        return;
      }

      if (this.get('categories')) {
        this.set('expanded', true);
      }
      var $dropdown = this.$()[0];

      this.$('a[data-drop-close]').on('click.category-drop', function() {
        self.close();
      });

      Em.run.next(function(){
        self.$('.cat a').add('html').on(self.get('clickEventName'), function(e) {
          var $target = $(e.target),
              closest = $target.closest($dropdown);

          if ($(e.currentTarget).hasClass('badge-wrapper')){
            self.close();
          }

          return ($(e.currentTarget).hasClass('badge-category') || (closest.length && closest[0] === $dropdown)) ? true : self.close();
        });
      });
    }
  },

  removeEvents: function(){
    $('html').off(this.get('clickEventName'));
    this.$('a[data-drop-close]').off('click.category-drop');
  },

  close: function() {
    this.removeEvents();
    this.set('expanded', false);
  },

  willDestroyElement: function() {
    this.removeEvents();
  }

});
