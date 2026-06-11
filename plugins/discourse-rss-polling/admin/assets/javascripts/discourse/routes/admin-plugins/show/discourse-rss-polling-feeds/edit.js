import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import RssPollingFeedSettings from "../../../../../admin/models/rss-polling-feed-settings";

export default class AdminPluginsShowDiscourseRssPollingFeedsEditRoute extends DiscourseRoute {
  async model(params) {
    const result = await RssPollingFeedSettings.show();
    return result.feed_settings.find(
      (feed) => feed.id === parseInt(params.id, 10)
    );
  }

  titleToken() {
    return i18n("admin.rss_polling.feeds.edit_header");
  }
}
