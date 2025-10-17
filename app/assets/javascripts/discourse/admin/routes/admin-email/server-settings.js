import DiscourseRoute from "discourse/routes/discourse";
import EmailSettings from "admin/models/email-settings";

export default class AdminEmailIndexRoute extends DiscourseRoute {
  model() {
    return EmailSettings.find();
  }
}
