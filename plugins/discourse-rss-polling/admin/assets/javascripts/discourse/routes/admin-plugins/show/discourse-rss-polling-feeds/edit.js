import { service } from "@ember/service";
import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import RssPollingFeedSettings from "../../../../../admin/models/rss-polling-feed-settings";

export default class AdminPluginsShowDiscourseRssPollingFeedsEditRoute extends DiscourseRoute {
  @service router;

  async model(params) {
    const id = parseInt(params.id, 10);
    const feedRequest = RssPollingFeedSettings.find(id);
    const historyRequest = RssPollingFeedSettings.history(id);

    let feed;
    try {
      feed = await feedRequest;
    } catch {
      historyRequest.catch(() => {});
      this.router.replaceWith("adminPlugins.show.discourse-rss-polling-feeds");
      return;
    }

    return { feed, history: await historyRequest };
  }

  titleToken() {
    return i18n("admin.rss_polling.feeds.edit_header");
  }
}
