import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  showFooter: true,

  setupController(controller, user) {
    controller.reset();
    controller.setProperties({
      model: user,
      newNameInput: user.get('name')
    });
  }
});
