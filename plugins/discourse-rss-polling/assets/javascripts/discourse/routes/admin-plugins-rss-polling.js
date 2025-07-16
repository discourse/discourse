import DiscourseRoute from "discourse/routes/discourse";
import RssPollingFeedSettings from "../../admin/models/rss-polling-feed-settings";

export default class AdminPluginsRssPolling extends DiscourseRoute {
  model() {
    return RssPollingFeedSettings.show().then((result) => result.feed_settings);
  }

  setupController(controller, model) {
    model.forEach((setting) => {
      setting.disabled = true;
      setting.editing = false;
    });

    controller.setProperties({
      model,
    });
  }
}
