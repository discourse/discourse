import { withPluginApi } from "discourse/lib/plugin-api";
import { i18n } from "discourse-i18n";
import {
  birthday,
  cakeday,
} from "discourse/plugins/discourse-cakeday/discourse/lib/cakeday";

function initializeCakeday(api) {
  const currentUser = api.getCurrentUser();
  if (!currentUser) {
    return;
  }

  const store = api.container.lookup("service:store");
  store.addPluralization("anniversary", "anniversaries");

  const siteSettings = api.container.lookup("service:site-settings");
  const emojiEnabled = siteSettings.enable_emoji;
  const cakedayEnabled = siteSettings.cakeday_enabled;
  const birthdayEnabled = siteSettings.cakeday_birthday_enabled;

  if (cakedayEnabled) {
    api.addTrackedPostProperties("user_cakedate");

    api.addPosterIcon((_, { user_cakedate, user_id }) => {
      if (cakeday(user_cakedate)) {
        let result = {};

        if (emojiEnabled) {
          result.emoji = siteSettings.cakeday_emoji;
        } else {
          result.icon = "cake-candles";
        }

        if (user_id === currentUser?.id) {
          result.title = i18n("user.anniversary.user_title");
        } else {
          result.title = i18n("user.anniversary.title");
        }

        return result;
      }
    });
  }

  if (birthdayEnabled) {
    api.addTrackedPostProperties("user_birthdate");

    api.addPosterIcon((_, { user_birthdate, user_id }) => {
      if (birthday(user_birthdate)) {
        let result = {};

        if (emojiEnabled) {
          result.emoji = siteSettings.cakeday_birthday_emoji;
        } else {
          result.icon = "cake-candles";
        }

        if (user_id === currentUser?.id) {
          result.title = i18n("user.date_of_birth.user_title");
        } else {
          result.title = i18n("user.date_of_birth.title");
        }

        return result;
      }
    });
  }

  if (cakedayEnabled || birthdayEnabled) {
    if (cakedayEnabled) {
      api.addCommunitySectionLink(
        {
          name: "anniversaries",
          route: "cakeday.anniversaries.today",
          title: i18n("anniversaries.title"),
          text: i18n("anniversaries.title"),
          icon: "cake-candles",
        },
        true
      );
    }

    if (birthdayEnabled) {
      api.addCommunitySectionLink(
        {
          name: "birthdays",
          route: "cakeday.birthdays.today",
          title: i18n("birthdays.title"),
          text: i18n("birthdays.title"),
          icon: "cake-candles",
        },
        true
      );
    }
  }
}

export default {
  name: "cakeday",

  initialize() {
    withPluginApi("0.1", (api) => initializeCakeday(api));
  },
};
