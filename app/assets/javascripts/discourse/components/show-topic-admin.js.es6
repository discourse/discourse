export default Em.Component.extend({
  tagName: "button",
  classNames: ["btn", "no-text", "show-topic-admin"],
  attributeBindings: ["title"],
  title: I18n.t("topic_admin_menu"),

  render: function(buffer) {
    buffer.push("<i class='fa fa-wrench'></i>");
  },

  click: function() {
    var $target = this.$(),
        position = $target.position(),
        width = $target.innerWidth();
    var location = {
      position: "fixed",
      left: position.left + width,
      top: position.top,
    };
    this.appEvents.trigger("topic-admin-menu:open", location);
    this.sendAction("show");
    return false;
  }
});
