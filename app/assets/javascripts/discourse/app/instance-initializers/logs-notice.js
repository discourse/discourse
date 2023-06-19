import LogsNotice from "discourse/services/logs-notice";
import Singleton from "discourse/mixins/singleton";
let initializedOnce = false;

export default {
  after: "message-bus",

  initialize(owner) {
    if (initializedOnce) {
      return;
    }

    const siteSettings = owner.lookup("service:site-settings");
    const messageBus = owner.lookup("service:message-bus");
    const keyValueStore = owner.lookup("service:key-value-store");
    const currentUser = owner.lookup("service:current-user");
    LogsNotice.reopenClass(Singleton, {
      createCurrent() {
        return this.create({
          messageBus,
          keyValueStore,
          siteSettings,
          currentUser,
        });
      },
    });

    initializedOnce = true;
  },
};
