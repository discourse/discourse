import { ajax } from "discourse/lib/ajax";

export default Discourse.Route.extend({
  titleToken() {
    return I18n.t("login.title");
  },

  model(params) {
    return ajax(`/session/email-login/${params.token}`);
  }
});
