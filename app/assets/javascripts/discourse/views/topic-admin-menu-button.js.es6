import ButtonView from "discourse/views/button";

export default ButtonView.extend({
  classNameBindings: [":no-text"],
  helpKey: "topic_admin_menu",

  renderIcon: function(buffer) {
    buffer.push("<i class='fa fa-wrench'></i>");
  },

  click: function() {
    var offset = this.$().offset();
    var location = {
      position: "absolute",
      left: offset.left,
      top: offset.top,
    };
    this.get("controller").appEvents.trigger("topic-admin-menu:open", location);
    return this.get("controller").send("showTopicAdminMenu");
  }
});
