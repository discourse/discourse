Discourse.DiscourseCategorydropComponent = Ember.Component.extend({

  classNameBindings: ['category::no-category', 'categories:has-drop'],
  tagName: 'li',

  iconClass: function() {
    if (this.get('expanded')) { return "icon icon-caret-down"; }
    return "icon icon-caret-right";
  }.property('expanded'),

  actions: {
    expand: function() {
      if (this.get('expanded')) {
        this.close();
        return;
      }

      if (this.get('categories')) {
        this.set('expanded', true);
      }

      var self = this,
          $dropdown = this.$()[0];

      $('html').on('click.category-drop', function(e) {
        var closest = $(e.target).closest($dropdown);
        return (closest.length && closest[0] === $dropdown) ? true : self.close();
      });
    }
  },

  close: function() {
    $('html').off('click.category-drop');
    this.set('expanded', false);
  },

  didInsertElement: function() {
  },

  willDestroyElement: function() {
    $('html').off('click.category-drop');
  }

});
