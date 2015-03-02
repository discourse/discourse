export default Ember.Component.extend({
  classNameBindings: [':featured-topic'],

  click(e) {
    const $target = $(e.target);
    if ($target.closest('.last-posted-at').length) {
      this.sendAction('action', {topic: this.get('topic'), position: $target.offset()});
      return false;
    }
  }
});
