/**
  This view handles the rendering of a list

  @class ListView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.ListView = Discourse.View.extend({
  templateName: 'list/list',
  composeViewBinding: Ember.Binding.oneWay('Discourse.composeView'),

  // The window has been scrolled
  scrolled: function(e) {
    var currentView;
    currentView = this.get('container.currentView');
    return currentView ? typeof currentView.scrolled === "function" ? currentView.scrolled(e) : void 0 : void 0;
  },

  createTopicText: function() {
    if (this.get('controller.category.name')) {
      return I18n.t("topic.create_in", {
        categoryName: this.get('controller.category.name')
      });
    } else {
      return I18n.t("topic.create");
    }
  }.property('controller.category.name')

});


