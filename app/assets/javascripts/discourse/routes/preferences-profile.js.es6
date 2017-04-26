import RestrictedUserRoute from "discourse/routes/restricted-user";

export default RestrictedUserRoute.extend({
  setupController(controller, user) {
    controller.setProperties({
      model: user,
      newNameInput: user.get('name')
    });
  }
});
