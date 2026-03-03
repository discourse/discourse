import { TrackedArray } from "@ember-compat/tracked-built-ins";
import DiscourseRoute from "discourse/routes/discourse";
import RssPollingFeedSettings from "../../../admin/models/rss-polling-feed-settings";

export default class AdminPluginsRssPolling extends DiscourseRoute {
  async model() {
    const result = await RssPollingFeedSettings.show();
    return new TrackedArray(result.feed_settings);
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
