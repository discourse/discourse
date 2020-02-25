import RestrictedUserRoute from "discourse/routes/restricted-user";
import { set } from "@ember/object";

export default RestrictedUserRoute.extend({
  showFooter: true,
  setupController(controller, model) {
    if (!model.user_option.timezone) {
      set(model, "user_option.timezone", moment.tz.guess());
    }

    controller.set("model", model);
  }
});
