import I18n from "I18n";
import DiscourseRoute from "discourse/routes/discourse";
import { ajax } from "discourse/lib/ajax";

export default DiscourseRoute.extend({
  titleToken() {
    return I18n.t("login.title");
  },

  model(params) {
    return ajax(`/session/email-login/${params.token}.json`);
  }
});
