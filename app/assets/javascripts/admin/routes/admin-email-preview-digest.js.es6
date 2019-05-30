import {
  default as EmailPreview,
  oneWeekAgo
} from "admin/models/email-preview";

export default Discourse.Route.extend({
  model() {
    return EmailPreview.findDigest(this.currentUser.username);
  },

  afterModel(model) {
    const controller = this.controllerFor("adminEmailPreviewDigest");
    controller.setProperties({
      model,
      username: this.currentUser.username,
      lastSeen: oneWeekAgo(),
      showHtml: true
    });
  }
});
