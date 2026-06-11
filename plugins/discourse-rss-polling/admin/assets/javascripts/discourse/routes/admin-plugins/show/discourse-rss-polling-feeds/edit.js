import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import RssPollingFeedSettings from "../../../../../admin/models/rss-polling-feed-settings";

export default class AdminPluginsShowDiscourseRssPollingFeedsEditRoute extends DiscourseRoute {
  @service router;

  async model(params) {
    const result = await RssPollingFeedSettings.show();
    const feed = result.feed_settings.find(
      (item) => item.id === parseInt(params.id, 10)
    );

    if (!feed) {
      this.router.replaceWith("adminPlugins.show.discourse-rss-polling-feeds");
      return;
    }

    return feed;
  }

  titleToken() {
    return i18n("admin.rss_polling.feeds.edit_header");
  }
}
