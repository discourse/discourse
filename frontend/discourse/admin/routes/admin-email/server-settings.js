import EmailSettings from "discourse/admin/models/email-settings";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminEmailIndexRoute extends DiscourseRoute {
  model() {
    return EmailSettings.find();
  }
}
