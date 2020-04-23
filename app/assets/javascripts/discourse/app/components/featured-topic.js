import Component from "@ember/component";
export default Component.extend({
  classNameBindings: [":featured-topic"],

  click(e) {
    const $target = $(e.target);
    if ($target.closest(".last-posted-at").length) {
      this.appEvents.trigger("topic-entrance:show", {
        topic: this.topic,
        position: $target.offset()
      });
      return false;
    }
  }
});
