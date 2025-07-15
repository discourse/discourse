import Controller from "@ember/controller";
import { action, set } from "@ember/object";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";
import { isBlank } from "@ember/utils";
import { observes } from "@ember-decorators/object";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import RssPollingFeedSettings from "../../admin/models/rss-polling-feed-settings";

export default class AdminPluginsRssPollingController extends Controller {
  @service dialog;

  @alias("model") feedSettings;

  saving = false;
  valid = false;
  disabled = true;

  @discourseComputed("valid", "saving")
  unsavable(valid, saving) {
    return !valid || saving;
  }

  // TODO: extract feed setting into its own component && more validation
  @observes("feedSettings.@each.{feed_url,author_username}")
  validate() {
    let overallValidity = true;

    this.get("feedSettings").forEach((feedSetting) => {
      const localValidity =
        !isBlank(feedSetting.feed_url) && !isBlank(feedSetting.author_username);
      set(feedSetting, "valid", localValidity);
      overallValidity = overallValidity && localValidity;
    });

    this.set("valid", overallValidity);
  }

  @action
  create() {
    let newSetting = {
      feed_url: null,
      author_username: null,
      discourse_category_id: null,
      discourse_tags: null,
      feed_category_filter: null,
      disabled: false,
      editing: true,
    };

    this.get("feedSettings").addObject(newSetting);
  }

  @action
  destroyFeedSetting(setting) {
    this.dialog.deleteConfirm({
      message: i18n("admin.rss_polling.destroy_feed.confirm"),
      didConfirm: async () => {
        try {
          await RssPollingFeedSettings.deleteFeed(setting);
          this.get("feedSettings").removeObject(setting);
        } catch (error) {
          popupAjaxError(error);
        } finally {
          this.set("saving", false);
        }
      },
    });
  }

  @action
  editFeedSetting(setting) {
    set(setting, "disabled", false);
    set(setting, "editing", true);
  }

  @action
  cancelEdit(setting) {
    if (!setting.id) {
      this.get("feedSettings").removeObject(setting);
    }
    set(setting, "disabled", true);
    set(setting, "editing", false);
  }

  @action
  async updateFeedSetting(setting) {
    this.set("saving", true);

    try {
      await RssPollingFeedSettings.updateFeed(setting);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.set("saving", false);
      set(setting, "disabled", true);
      set(setting, "editing", false);
    }
  }

  @action
  updateAuthorUsername(setting, selected) {
    set(setting, "author_username", selected.firstObject);
  }
}
