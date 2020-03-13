import DiscourseRoute from "discourse/routes/discourse";

export default DiscourseRoute.extend({
  beforeModel: function() {
    this.replaceWith("userInvited.show", "pending");
  }
});
