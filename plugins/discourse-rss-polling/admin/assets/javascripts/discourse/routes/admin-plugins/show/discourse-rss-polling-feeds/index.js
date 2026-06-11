import { trackedArray } from "@ember/reactive/collections";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import RssPollingFeedSettings from "../../../../../admin/models/rss-polling-feed-settings";

export default class AdminPluginsShowDiscourseRssPollingFeedsIndexRoute extends DiscourseRoute {
  async model() {
    const result = await RssPollingFeedSettings.show();
    return trackedArray(result.feed_settings);
  }

  titleToken() {
    return i18n("admin.rss_polling.feeds.title");
  }
}
