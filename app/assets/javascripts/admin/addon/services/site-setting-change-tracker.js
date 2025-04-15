import { tracked } from "@glimmer/tracking";
import Service, { service } from "@ember/service";
import { TrackedSet } from "@ember-compat/tracked-built-ins";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import { DEFAULT_TEXT_SIZES } from "admin/lib/constants";
import SiteSetting from "admin/models/site-setting";
import SiteSettingDefaultCategoriesModal from "../components/modal/site-setting-default-categories";

export default class SiteSettingChangeTracker extends Service {
  @service dialog;
  @service modal;
  @service session;
  @service site;
  @service siteSettings;

  @tracked dirtySiteSettings = new TrackedSet();

  add(setting) {
    this.dirtySiteSettings.add(setting);
  }

  remove(setting) {
    this.dirtySiteSettings.delete(setting);
  }

  async save() {
    const params = {};

    this.#startSaving();

    try {
      let reload = false;
      let confirm = true;

      // Settings with custom confirmation messages.
      if (this.#requiresConfirmation.length > 0) {
        for (let setting of this.#requiresConfirmation) {
          confirm = await this.confirmChanges(setting);

          if (!confirm) {
            this.#stopSaving();

            return;
          }
        }
      }

      // Settings requiring confirmation because they
      // affect existing users.
      if (this.#affectsExistingUsers.length > 0) {
        for (let setting of this.#affectsExistingUsers) {
          await this.configureBackfill(setting);
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
        setting.validationMessage = null;
        setting.buffered.applyChanges();
        if (setting.requiresReload) {
          reload = setting.afterSave;
        }
      });

      this.#stopSaving();
      this.dirtySiteSettings.clear();

      if (reload) {
        reload();
      }
    } catch (error) {
      this.#stopSaving();
      popupAjaxError(error);
    }
  }

  discard() {
    this.dirtySiteSettings.forEach((setting) =>
      setting.buffered.discardChanges()
    );
    this.dirtySiteSettings.clear();
  }

  async confirmChanges(setting) {
    const settingKey = setting.buffered.get("setting");

    return new Promise((resolve) => {
      // Fallback is needed in case the setting does not have a custom confirmation
      // prompt/confirm defined.
      this.dialog.alert({
        message: i18n(
          `admin.site_settings.requires_confirmation_messages.${settingKey}.prompt`,
          {
            translatedFallback: i18n(
              "admin.site_settings.requires_confirmation_messages.default.prompt"
            ),
          }
        ),
        buttons: [
          {
            label: i18n(
              `admin.site_settings.requires_confirmation_messages.${settingKey}.confirm`,
              {
                translatedFallback: i18n(
                  "admin.site_settings.requires_confirmation_messages.default.confirm"
                ),
              }
            ),
            class: "btn-primary",
            action: () => resolve(true),
          },
          {
            label: i18n("no_value"),
            class: "btn-default",
            action: () => resolve(false),
          },
        ],
      });
    });
  }

  async confirmTransition() {
    await new Promise((resolve) => {
      this.dialog.confirm({
        message: i18n("admin.site_settings.dirty_banner", {
          count: this.count,
        }),
        confirmButtonLabel: this.saveLabel,
        cancelButtonLabel: this.discardLabel,
        didConfirm: async () => {
          await this.save();
          resolve(true);
        },
        didCancel: () => {
          this.discard();
          resolve(false);
        },
      });
    });
  }

  async configureBackfill(setting) {
    const key = setting.buffered.get("setting");

    const data = {
      [key]: setting.buffered.get("value"),
    };

    const result = await ajax(`/admin/site_settings/${key}/user_count.json`, {
      type: "PUT",
      data,
    });

    const count = result.user_count;

    if (count > 0) {
      await this.modal.show(SiteSettingDefaultCategoriesModal, {
        model: {
          siteSetting: { count, key: key.replaceAll("_", " ") },
          setUpdateExistingUsers: setting.setUpdateExistingUsers,
        },
      });
    }
  }

  #startSaving() {
    this.dirtySiteSettings.forEach((setting) => {
      setting.isSaving = true;
    });
  }

  #stopSaving() {
    this.dirtySiteSettings.forEach((setting) => {
      setting.isSaving = false;
    });
  }

  refreshPage(params) {
    if (params.base_font) {
      document.documentElement.style.setProperty(
        "--font-family",
        params.base_font
      );
    }
    if (params.heading_font) {
      document.documentElement.style.setProperty(
        "--heading-font-family",
        params.heading_font
      );
    }
    if (params.default_text_size) {
      DEFAULT_TEXT_SIZES.forEach((size) => {
        document.documentElement.classList.remove(`text-size-${size}`);
      });
      document.documentElement.classList.add(
        `text-size-${params.default_text_size}`
      );
    }

    let logo;

    if (this.site.mobileView) {
      if (
        this.session.defaultColorSchemeIsDark ||
        this.session.darkModeAvailable
      ) {
        logo = params.mobile_logo_dark;
      } else {
        logo = params.mobile_logo;
      }
    }

    if (!logo && this.session.defaultColorSchemeIsDark) {
      logo = params.logo_dark;
    }

    if (!logo) {
      logo = params.logo;
    }

    // Force reload when switching from text logo to image logo and vice versa
    if (
      (!this.siteSettings.logo && document.getElementById("site-logo")) ||
      (this.siteSettings.logo && !document.getElementById("site-logo"))
    ) {
      window.location.reload();
    } else if (logo) {
      document.getElementById("site-logo").setAttribute("src", logo);
    }
  }

  get count() {
    return this.dirtySiteSettings.size;
  }

  get hasUnsavedChanges() {
    return this.count > 0;
  }

  get saveLabel() {
    const count = this.hasUnsavedChanges ? "other" : "one";

    return `admin.site_settings.save.${count}`;
  }

  get discardLabel() {
    const count = this.hasUnsavedChanges ? "other" : "one";

    return `admin.site_settings.discard.${count}`;
  }

  get #requiresConfirmation() {
    return [...this.dirtySiteSettings].filter(
      (setting) => setting.requiresConfirmation
    );
  }

  get #affectsExistingUsers() {
    return [...this.dirtySiteSettings].filter(
      (setting) => setting.affectsExistingUsers
    );
  }
}
