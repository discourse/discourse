(function() {

  window.Discourse.EmbeddedPostView = Ember.View.extend({
    templateName: 'embedded_post',
    classNames: ['reply'],
    didInsertElement: function() {
      var postView;
      postView = this.get('postView') || this.get('parentView.postView');
      return postView.get('screenTrack').track(this.get('elementId'), this.get('post.post_number'));
    }
  });

}).call(this);
