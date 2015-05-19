function scrollTop() {
  if (Discourse.URL.isJumpScheduled()) { return; }
  Ember.run.schedule('afterRender', function() {
    $(document).scrollTop(0);
  });
}

export default Ember.Mixin.create({
  _scrollTop: scrollTop.on('didInsertElement')
});

export { scrollTop };
