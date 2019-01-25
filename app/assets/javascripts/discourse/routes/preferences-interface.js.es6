import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  showFooter: true,

  setupController(controller, user) {
    let textSize = $.cookie("text_size") || user.get("user_option.text_size");
    controller.setProperties({
      model: user,
      textSize
    });
  }
});
