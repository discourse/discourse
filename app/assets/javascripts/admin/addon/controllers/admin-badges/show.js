import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse-common/lib/get-url";
import I18n from "discourse-i18n";

export default class AdminBadgesShowController extends Controller {
  @service router;
  @service toasts;
  @service dialog;

  @controller adminBadges;

  @tracked model;
  @tracked saving = false;
  @tracked selectedGraphicType = null;
  @tracked userBadges;
  @tracked userBadgesAll;

  @action
  currentBadgeGrouping(data) {
    return this.badgeGroupings.find((bg) => bg.id === data.badge_grouping_id)
      ?.name;
  }

  get badgeTypes() {
    return this.adminBadges.badgeTypes;
  }

  get badgeGroupings() {
    return this.adminBadges.badgeGroupings;
  }

  get badgeTriggers() {
    return this.adminBadges.badgeTriggers;
  }

  get protectedSystemFields() {
    return this.adminBadges.protectedSystemFields;
  }

  get readOnly() {
    return this.model.system;
  }

  setup() {
    this.saving = false;

    // this is needed because the model doesnt have default values
    // Using `set` here isn't ideal, but we don't know that tracking is set up on the model yet.
    if (this.model) {
      if (!this.model.badge_type_id) {
        this.model.set("badge_type_id", this.badgeTypes?.[0]?.id);
      }

      if (!this.model.badge_grouping_id) {
        this.model.set("badge_grouping_id", this.badgeGroupings?.[0]?.id);
      }

      if (!this.model.trigger) {
        this.model.set("trigger", this.badgeTriggers?.[0]?.id);
      }
    }
  }

  hasQuery(query) {
    return query?.trim?.()?.length > 0;
  }

  get textCustomizationPrefix() {
    return `badges.${this.model.i18n_name}.`;
  }

  @action
  onSetImage(upload, { set }) {
    if (upload) {
      set("image_upload_id", upload.id);
      set("image_url", getURL(upload.url));
      set("icon", "");
      this.model.icon = undefined;
      this.model.image = getURL(upload.url);
    } else {
      set("image_upload_id", "");
      set("image_url", "");
    }
  }

  @action
  onSetIcon(value, { set }) {
    this.model.set("icon", value);
    set("icon", value);
    set("image_upload_id", "");
    set("image_url", "");
  }

  @action
  onSetName(value, { set }) {
    this.model.set("name", value);
    set("name", value);
  }

  @action
  showPreview(badge, explain, event) {
    event?.preventDefault();
    this.send("preview", badge, explain);
  }

  @action
  async handleSubmit(formData) {
    if (this.saving) {
      return;
    }

    let fields = [
      "allow_title",
      "multiple_grant",
      "listable",
      "auto_revoke",
      "enabled",
      "show_posts",
      "target_posts",
      "name",
      "description",
      "long_description",
      "icon",
      "image_upload_id",
      "query",
      "badge_grouping_id",
      "trigger",
      "badge_type_id",
    ];

    if (formData.system) {
      const protectedFields = this.protectedSystemFields || [];
      fields = fields.filter((f) => !protectedFields.includes(f));
    }

    this.saving = true;

    const data = {};
    fields.forEach(function (field) {
      data[field] = formData[field];
    });

    const newBadge = !this.model.id;

    try {
      this.model = await this.model.save(data);

      this.toasts.success({ data: { message: I18n.t("saved") } });

      if (newBadge) {
        const adminBadges = this.get("adminBadges.model");
        if (!adminBadges.includes(this.model)) {
          adminBadges.pushObject(this.model);
        }
        return this.router.transitionTo("adminBadges.show", this.model.id);
      }
    } catch (error) {
      return popupAjaxError(error);
    } finally {
      this.saving = false;
    }
  }

  @action
  async handleDelete() {
    if (!this.model?.id) {
      return this.router.transitionTo("adminBadges.index");
    }

    const adminBadges = this.adminBadges.model;
    return this.dialog.yesNoConfirm({
      message: I18n.t("admin.badges.delete_confirm"),
      didConfirm: async () => {
        try {
          await this.model.destroy();
          adminBadges.removeObject(this.model);
          this.router.transitionTo("adminBadges.index");
        } catch {
          this.dialog.alert(I18n.t("generic_error"));
        }
      },
    });
  }

  @action
  async onToggleBadge(enabled, { set }) {
    try {
      await this.model.save({ enabled });
      this.toasts.success({ data: { message: I18n.t("saved") } });
    } catch (error) {
      set("enabled", !enabled);
      return popupAjaxError(error);
    }
  }
}
