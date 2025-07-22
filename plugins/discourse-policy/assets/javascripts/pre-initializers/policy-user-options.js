import EmailsController from "discourse/controllers/preferences/emails";
import { withPluginApi } from "discourse/lib/plugin-api";

const SEND_EMAIL_NOTIFICATIONS_FIELD = "policy_email_frequency";

export default {
  name: "policy-user-options",

  initialize(container) {
    withPluginApi("0.8.7", (api) => {
      const siteSettings = container.lookup("service:site-settings");
      if (siteSettings.policy_enabled) {
        api.addSaveableUserOptionField(SEND_EMAIL_NOTIFICATIONS_FIELD);
      }
    });

    EmailsController.reopen({
      init() {
        this._super(...arguments);
        this.saveAttrNames.push(SEND_EMAIL_NOTIFICATIONS_FIELD);
      },
    });
  },
};
