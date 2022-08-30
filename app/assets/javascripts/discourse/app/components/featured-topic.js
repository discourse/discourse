import Component from "@ember/component";

export default Component.extend({
  classNameBindings: [":featured-topic"],
  attributeBindings: ["topic.id:data-topic-id"],

  click(e) {
    if (e.target.closest(".last-posted-at")) {
      this.appEvents.trigger("topic-entrance:show", {
        topic: this.topic,
        position: $(e.target).offset(),
      });
      return false;
    }
  },
});
