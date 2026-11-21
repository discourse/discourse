import DiscourseRoute from "discourse/routes/discourse";
import { listRegistrationForms } from "discourse/plugins/discourse-events/discourse/lib/registration-forms";

export default class RegistrationFormsIndexRoute extends DiscourseRoute {
  model() {
    return listRegistrationForms({ includeUsage: true });
  }
}
