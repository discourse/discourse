import { apiInitializer } from "discourse/lib/api";
import { number } from "discourse/lib/formatter";
import { i18n } from "discourse-i18n";

export default apiInitializer((api) => {
  api.addAboutPageActivity("voice_users", (periods) => {
    const count = periods["7_days"];
    if (api.container.lookup("service:site-settings").voice_enabled && count) {
      return {
        icon: "microphone",
        class: "voice-users",
        activityText: i18n("voice.about.participants", {
          count,
          formatted_number: number(count),
        }),
        period: i18n("about.activities.periods.last_7_days"),
      };
    }
  });
});
