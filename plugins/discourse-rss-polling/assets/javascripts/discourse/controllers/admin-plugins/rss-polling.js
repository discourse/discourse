import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action, set } from "@ember/object";
import { service } from "@ember/service";
import { isBlank } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import {
  addUniqueValueToArray,
  removeValueFromArray,
} from "discourse/lib/array-tools";
import { bind } from "discourse/lib/decorators";
import { i18n } from "discourse-i18n";
import RssPollingFeedSettings from "../../../admin/models/rss-polling-feed-settings";

export default class AdminPluginsRssPollingController extends Controller {
  @service dialog;

  @tracked saving = false;
  @tracked valid = false;
  @tracked disabled = true;

  get feedSettings() {
    return this.model;
  }

  get unsavable() {
    return !this.valid || this.saving;
  }

  // TODO: extract feed setting into its own component && more validation
  @bind
  validate() {
    let overallValidity = true;

    this.feedSettings.forEach((feedSetting) => {
      const localValidity =
        !isBlank(feedSetting.feed_url) && !isBlank(feedSetting.author_username);
      set(feedSetting, "valid", localValidity);
      overallValidity = overallValidity && localValidity;
    });

    if (this.valid !== overallValidity) {
      this.valid = overallValidity;
    }
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

    addUniqueValueToArray(this.feedSettings, newSetting);

    this.validate();
  }

  @action
  destroyFeedSetting(setting) {
    this.dialog.deleteConfirm({
      message: i18n("admin.rss_polling.destroy_feed.confirm"),
      didConfirm: async () => {
        try {
          await RssPollingFeedSettings.deleteFeed(setting);
          removeValueFromArray(this.feedSettings, setting);
        } catch (error) {
          popupAjaxError(error);
        } finally {
          this.saving = false;
        }
      },
    });

    this.validate();
  }

  @action
  editFeedSetting(setting) {
    set(setting, "disabled", false);
    set(setting, "editing", true);

    this.validate();
  }

  @action
  cancelEdit(setting) {
    if (!setting.id) {
      removeValueFromArray(this.feedSettings, setting);
    }
    set(setting, "disabled", true);
    set(setting, "editing", false);

    this.validate();
  }

  @action
  async updateFeedSetting(setting) {
    this.saving = true;

    try {
      await RssPollingFeedSettings.updateFeed(setting);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.saving = false;

      set(setting, "disabled", true);
      set(setting, "editing", false);
    }

    this.validate();
  }

  @action
  updateAuthorUsername(setting, selected) {
    set(setting, "author_username", selected[0]);

    this.validate();
  }

  @action
  updateSettingProperty(setting, property, event) {
    set(setting, property, event.target.value);

    this.validate();
  }
}
