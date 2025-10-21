import DiscourseRoute from "discourse/routes/discourse";
import EmailPreview, { oneWeekAgo } from "admin/models/email-preview";

export default class AdminEmailPreviewDigestRoute extends DiscourseRoute {
  model() {
    return EmailPreview.findDigest(this.currentUser.get("username"));
  }

  afterModel(model) {
    const controller = this.controllerFor("adminEmail.previewDigest");
    controller.setProperties({
      model,
      username: this.currentUser.get("username"),
      lastSeen: oneWeekAgo(),
      showHtml: true,
    });
  }
}
