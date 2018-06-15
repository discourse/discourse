export default Discourse.Route.extend({
  beforeModel: function() {
    this.replaceWith("userInvited.show", "pending");
  }
});
