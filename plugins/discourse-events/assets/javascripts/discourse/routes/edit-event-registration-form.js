import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import { fetchRegistrationForm } from "../lib/registration-forms.js";

export default class EditEventRegistrationFormRoute extends DiscourseRoute {
  model({ id }) {
    return fetchRegistrationForm(id, { edit: true });
  }

  titleToken() {
    return i18n("event_registration.library.edit");
  }
}
