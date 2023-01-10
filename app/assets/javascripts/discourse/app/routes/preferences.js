import RestrictedUserRoute from "discourse/routes/restricted-user";
import I18n from "I18n";

export default RestrictedUserRoute.extend({
  model() {
    return this.modelFor("user");
  },

  titleToken() {
    return I18n.t("user.preferences");
  },
});
