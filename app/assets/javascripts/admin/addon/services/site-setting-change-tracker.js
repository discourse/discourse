import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { TrackedSet } from "@ember-compat/tracked-built-ins";
import { popupAjaxError } from "discourse/lib/ajax-error";
import SiteSetting from "admin/models/site-setting";

export default class SiteSettingChangeTracker extends Service {
  @service modal;

  @tracked dirtySiteSettings = new TrackedSet();

  add(settingComponent) {
    this.dirtySiteSettings.add(settingComponent);
  }

  remove(settingComponent) {
    this.dirtySiteSettings.delete(settingComponent);
  }

  async save() {
    const params = {};

    this.dirtySiteSettings.forEach((setting) => {
      setting.set("isSaving", true);
    });

    try {
      let reload = false;
      let confirm = true;

      // Settings with custom confirmation messages.
      if (this.#requiresConfirmation.length > 0) {
        for (let setting of this.#requiresConfirmation) {
          confirm = await setting.confirmChanges();
        }

        if (!confirm) {
          return;
        }
      }

      // Settings requiring confirmation because they
      // affect existing users.
      if (this.#affectsExistingUsers.length > 0) {
        for (let setting of this.#affectsExistingUsers) {
          await setting.configureBackfill();
        }
      }

      this.dirtySiteSettings.forEach((setting) => {
        params[setting.buffered.get("setting")] = {
          value: setting.buffered.get("value"),
          backfill: !!setting.updateExistingUsers,
        };
      });

      await SiteSetting.bulkUpdate(params);

      this.dirtySiteSettings.forEach((setting) => {
        setting.set("validationMessage", null);
        setting.buffered.applyChanges();
        if (setting.requiresReload()) {
          reload = setting.afterSave;
        }
      });

      if (reload) {
        reload();
      }
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.dirtySiteSettings.forEach((setting) =>
        setting.set("isSaving", false)
      );
    }
  }

  discard() {
    this.dirtySiteSettings.forEach((siteSetting) => siteSetting.cancel());
  }

  get count() {
    return this.dirtySiteSettings.size;
  }

  get #requiresConfirmation() {
    return [...this.dirtySiteSettings].filter((setting) =>
      setting.requiresConfirmation()
    );
  }

  get #affectsExistingUsers() {
    return [...this.dirtySiteSettings].filter((setting) =>
      setting.affectsExistingUsers()
    );
  }
}
