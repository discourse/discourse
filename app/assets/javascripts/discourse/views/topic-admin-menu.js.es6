/**
  This view is used for rendering the topic admin menu

  @class TopicAdminMenuView
  @extends Ember.View
  @namespace Discourse
  @module Discourse
**/
export default Ember.View.extend({
  classNameBindings: ["controller.menuVisible::hidden", ":topic-admin-menu"],

  _setup: function() {
    var self = this;

    this.appEvents.on("topic-admin-menu:open", this, "_changeLocation");

    $("html").on("mouseup.discourse-topic-admin-menu", function(e) {
      var $target = $(e.target);
      if ($target.is("button") || self.$().has($target).length === 0) {
        self.get("controller").send("hide");
      }
    });
  }.on("didInsertElement"),

  _changeLocation: function(location) {
    var $this = this.$();
    switch (location.position) {
      case "absolute": {
        $this.css({
          position: "absolute",
          top: location.top - $this.innerHeight() + 5,
          left: location.left,
        });
        break;
      }
      case "fixed": {
        $this.css({
          position: "fixed",
          top: location.top,
          left: location.left - $this.innerWidth(),
        });
        break;
      }
    }
  },

  _cleanup: function() {
    $("html").off("mouseup.discourse-topic-admin-menu");
    this.appEvents.off("topic-admin-menu:open");
  }.on("willDestroyElement"),

});
