Discourse.ScrollTop = Em.Mixin.create({
  _scrollTop: function() {
    if (Discourse.URL.isJumpScheduled()) { return; }
    Em.run.schedule('afterRender', function() {
      $(document).scrollTop(0);
    });
  }.on('didInsertElement')
});
