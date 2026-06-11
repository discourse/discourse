import DiscourseRoute from "discourse/routes/discourse";
import { i18n } from "discourse-i18n";
import RssPollingFeedSettings from "../../../../../admin/models/rss-polling-feed-settings";

export default class AdminPluginsShowDiscourseRssPollingFeedsHistoryRoute extends DiscourseRoute {
  model(params) {
    return RssPollingFeedSettings.history(params.id);
  }

  titleToken() {
    return i18n("admin.rss_polling.history.title");
  }
}
