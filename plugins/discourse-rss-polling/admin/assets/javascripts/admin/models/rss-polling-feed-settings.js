import { ajax } from "discourse/lib/ajax";

export default {
  show() {
    return ajax("/admin/plugins/rss_polling/feed_settings.json");
  },

  updateFeed(feedSetting) {
    return ajax("/admin/plugins/rss_polling/feed_settings", {
      type: "PUT",
      contentType: "application/json",
      processData: false,
      data: JSON.stringify({ feed_setting: feedSetting }),
    });
  },

  deleteFeed(feedSetting) {
    return ajax("/admin/plugins/rss_polling/feed_settings", {
      type: "DELETE",
      contentType: "application/json",
      processData: false,
      data: JSON.stringify({ feed_setting: feedSetting }),
    });
  },

  testFeed(feedSetting) {
    return ajax("/admin/plugins/rss_polling/feed_settings/test", {
      type: "POST",
      data: {
        feed_url: feedSetting.feed_url,
        feed_category_filter: feedSetting.feed_category_filter,
      },
    });
  },
};
