(function() {

  window.Discourse.FeaturedTopicsView = Ember.View.extend({
    templateName: 'featured_topics',
    classNames: ['category-list-item'],
    init: function() {
      this._super();
      return this.set('context', this.get('content'));
    }
  });

}).call(this);
