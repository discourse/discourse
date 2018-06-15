export default Ember.Component.extend({
  classNameBindings: [":featured-topic"],

  click(e) {
    const $target = $(e.target);
    if ($target.closest(".last-posted-at").length) {
      this.appEvents.trigger("topic-entrance:show", {
        topic: this.get("topic"),
        position: $target.offset()
      });
      return false;
    }
  }
});
