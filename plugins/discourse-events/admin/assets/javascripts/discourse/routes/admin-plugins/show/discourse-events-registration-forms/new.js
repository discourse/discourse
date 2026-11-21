import DiscourseRoute from "discourse/routes/discourse";
import { newRegistrationForm } from "discourse/plugins/discourse-events/discourse/lib/registration-forms";

export default class RegistrationFormsNewRoute extends DiscourseRoute {
  model() {
    return newRegistrationForm();
  }
}
