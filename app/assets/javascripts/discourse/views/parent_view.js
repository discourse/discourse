(function() {

  window.Discourse.ParentView = Discourse.EmbeddedPostView.extend({
    previousPost: true,
    
    // Nice animation for when the replies appear
    didInsertElement: function() {
      var $parentPost;
      this._super();
      $parentPost = this.get('postView').$('section.parent-post');

      // Animate unless we're on a touch device
      if (Discourse.get('touch')) {
        return $parentPost.show();
      } else {
        return $parentPost.slideDown();
      }
    }
  });

}).call(this);
