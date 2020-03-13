import DiscourseRoute from "discourse/routes/discourse";
import EmailSettings from "admin/models/email-settings";

export default DiscourseRoute.extend({
  model() {
    return EmailSettings.find();
  }
});
