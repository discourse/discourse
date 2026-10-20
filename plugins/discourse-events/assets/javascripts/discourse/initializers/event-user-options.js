import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "event-user-options",

  initialize() {
    withPluginApi((api) => {
      api.addSaveableUserOption("event_reminder_preference");
    });
  },
};
