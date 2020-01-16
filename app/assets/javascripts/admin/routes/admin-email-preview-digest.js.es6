import DiscourseRoute from "discourse/routes/discourse";
import EmailPreview, { oneWeekAgo } from "admin/models/email-preview";

export default DiscourseRoute.extend({
  model() {
    return EmailPreview.findDigest(this.currentUser.get("username"));
  },

  afterModel(model) {
    const controller = this.controllerFor("adminEmailPreviewDigest");
    controller.setProperties({
      model,
      username: this.currentUser.get("username"),
      lastSeen: oneWeekAgo(),
      showHtml: true
    });
  }
});
