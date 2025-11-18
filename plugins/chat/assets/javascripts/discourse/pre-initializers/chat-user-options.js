import EmailsController from "discourse/controllers/preferences/emails";
import { withPluginApi } from "discourse/lib/plugin-api";

const FIELD_NAME = "chat_email_frequency";

export default {
  name: "chat-user-options",

  initialize(container) {
    withPluginApi((api) => {
      const siteSettings = container.lookup("service:site-settings");
      if (siteSettings.chat_enabled) {
        api.addSaveableUserOptionField(FIELD_NAME);
      }
    });

    EmailsController.reopen({
      init() {
        this._super(...arguments);
        this.saveAttrNames.push(FIELD_NAME);
      },
    });
  },
};
