import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import { listRegistrationForms } from "../lib/registration-forms.js";

export default class MyEventRegistrationFormsRoute extends DiscourseRoute {
  model() {
    return listRegistrationForms({ mine: true });
  }

  titleToken() {
    return i18n("event_registration.library.manage");
  }
}
