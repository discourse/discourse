import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNames: ["invite-list-user"],

  @computed("user.role")
  roleName(role) {
    return this.get("roles").findBy("id", role).label;
  },

  actions: {
    removeUser(user) {
      this.sendAction("removeUser", user);
    }
  }
});
