import { service } from "@ember/service";
import EmailPreview, { oneWeekAgo } from "discourse/admin/models/email-preview";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminEmailPreviewDigestRoute extends DiscourseRoute {
  @service siteSettings;

  async model() {
    const locale = this.#previewLocale();
    const [emailPreview, previewTypes] = await Promise.all([
      EmailPreview.findDigest(
        this.currentUser.get("username"),
        undefined,
        "digest",
        locale
      ),
      EmailPreview.findTypes(),
    ]);

    return { emailPreview, previewTypes };
  }

  setupController(controller, model) {
    super.setupController(controller, model.emailPreview);
    controller.setProperties({
      username: this.currentUser.get("username"),
      lastSeen: oneWeekAgo(),
      emailType: "digest",
      emailTemplates: model.previewTypes.email_templates,
      locale: this.#previewLocale(),
      showHtml: true,
    });
  }

  #previewLocale() {
    return this.currentUser.get("locale") || this.siteSettings.default_locale;
  }
}
