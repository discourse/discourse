import EmailPreview, { oneWeekAgo } from "discourse/admin/models/email-preview";
import DiscourseRoute from "discourse/routes/discourse";

export default class AdminEmailPreviewDigestRoute extends DiscourseRoute {
  async model(params) {
    const username = params.username || this.currentUser.username;
    const lastSeen = params.lastSeen || oneWeekAgo();
    const emailType = params.emailType || "digest";
    const locale = params.locale || null;
    const themeId = params.themeId || "";
    const [emailPreview, previewTypes] = await Promise.all([
      EmailPreview.findPreview(username, lastSeen, emailType, locale, themeId),
      EmailPreview.findTypes(),
    ]);
    return {
      emailPreview,
      previewTypes,
      username,
      lastSeen,
      emailType,
      locale,
      themeId,
    };
  }

  resetController(controller, isExiting) {
    if (isExiting) {
      controller.cancelRefresh();
    }
  }

  setupController(controller, model) {
    super.setupController(controller, model.emailPreview);
    controller.setProperties({
      username: model.username,
      lastSeen: model.lastSeen,
      emailType: model.emailType,
      locale: model.locale,
      themeId: model.themeId,
      emailTemplates: model.previewTypes.email_templates,
      messageTypes: model.previewTypes.message_types,
      brandingThemeOptions: model.previewTypes.branding_themes,
      showHtml: true,
      loading: false,
      sentEmail: false,
    });
    controller.set("renderedParameters", controller.previewParameters);
  }
}
