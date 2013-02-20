(function() {

  window.Discourse.ListView = Ember.View.extend({
    templateName: 'list/list',
    composeViewBinding: Ember.Binding.oneWay('Discourse.composeView'),
    categoriesBinding: 'Discourse.site.categories',
    /* The window has been scrolled
    */

    scrolled: function(e) {
      var currentView;
      currentView = this.get('container.currentView');
      return currentView ? typeof currentView.scrolled === "function" ? currentView.scrolled(e) : void 0 : void 0;
    },
    createTopicText: (function() {
      if (this.get('controller.category.name')) {
        return Em.String.i18n("topic.create_in", {
          categoryName: this.get('controller.category.name')
        });
      } else {
        return Em.String.i18n("topic.create");
      }
    }).property('controller.category.name')
  });

}).call(this);
