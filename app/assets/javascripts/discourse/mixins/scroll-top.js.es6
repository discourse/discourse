import DiscourseURL from 'discourse/lib/url';

function scrollTop() {
  if (DiscourseURL.isJumpScheduled()) { return; }
  Ember.run.schedule('afterRender', function() {
    $(document).scrollTop(0);
  });
}

export default Ember.Mixin.create({
  _scrollTop: scrollTop.on('didInsertElement')
});

export { scrollTop };
