import { ajax } from "discourse/lib/ajax";

export default {
  show() {
    return ajax("/admin/plugins/rss_polling/feed_settings.json");
  },

  find(id) {
    return ajax(`/admin/plugins/rss_polling/feed_settings/${id}.json`);
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
    return ajax(`/admin/plugins/rss_polling/feed_settings/${feedSetting.id}`, {
      type: "DELETE",
    });
  },

  setEnabled(feedSetting, enabled) {
    return ajax(
      `/admin/plugins/rss_polling/feed_settings/${feedSetting.id}/enabled`,
      {
        type: "PUT",
        data: { enabled },
      }
    );
  },

  history(id) {
    return ajax(`/admin/plugins/rss_polling/feed_settings/${id}/history.json`);
  },

  pollNow(id) {
    return ajax(`/admin/plugins/rss_polling/feed_settings/${id}/poll`, {
      type: "POST",
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

  categoryRequirements(categoryId) {
    return ajax(
      "/admin/plugins/rss_polling/feed_settings/category_requirements",
      {
        data: { category_id: categoryId },
      }
    );
  },
};
