(function() {

  window.Discourse.SelectedPostsView = Ember.View.extend({
    elementId: 'selected-posts',
    templateName: 'selected_posts',
    topicBinding: 'controller.content',
    classNameBindings: ['customVisibility'],
    customVisibility: (function() {
      if (!this.get('controller.multiSelect')) {
        return 'hidden';
      }
    }).property('controller.multiSelect')
  });

}).call(this);
