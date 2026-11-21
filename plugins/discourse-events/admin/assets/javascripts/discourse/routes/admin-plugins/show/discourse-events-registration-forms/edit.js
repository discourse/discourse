import DiscourseRoute from "discourse/routes/discourse";
import { fetchRegistrationForm } from "discourse/plugins/discourse-events/discourse/lib/registration-forms";

export default class RegistrationFormsEditRoute extends DiscourseRoute {
  model({ id }) {
    return fetchRegistrationForm(id, { edit: true });
  }
}
