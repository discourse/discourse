import LogsNotice from "discourse/services/logs-notice";
import Singleton from "discourse/mixins/singleton";
let initializedOnce = false;

export default {
  name: "logs-notice",
  after: "message-bus",

  initialize(container) {
    if (initializedOnce) {
      return;
    }

    const siteSettings = container.lookup("site-settings:main");
    const messageBus = container.lookup("message-bus:main");
    const keyValueStore = container.lookup("key-value-store:main");
    const currentUser = container.lookup("current-user:main");
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
