import Controller, { inject as controller } from "@ember/controller";
import { observes } from "@ember-decorators/object";
import I18n from "I18n";
import { bufferedProperty } from "discourse/mixins/buffered-content";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { next } from "@ember/runloop";
import { action } from "@ember/object";
import { inject as service } from "@ember/service";
import getURL from "discourse-common/lib/get-url";
import { tracked } from "@glimmer/tracking";

const IMAGE = "image";
const ICON = "icon";

// TODO: Stop using Mixin here
export default class AdminBadgesShowController extends Controller.extend(
  bufferedProperty("model")
) {
  @service router;
  @service dialog;
  @controller adminBadges;

  @tracked saving = false;
  @tracked savingStatus = "";
  @tracked selectedGraphicType = null;

  get badgeEnabledLabel() {
    if (this.buffered.get("enabled")) {
      return "admin.badges.enabled";
    } else {
      return "admin.badges.disabled";
    }
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
    return this.buffered.get("system");
  }

  get showDisplayName() {
    return this.name !== this.displayName;
  }

  get iconSelectorSelected() {
    return this.selectedGraphicType === ICON;
  }

  get imageUploaderSelected() {
    return this.selectedGraphicType === IMAGE;
  }

  init() {
    super.init(...arguments);

    // this is needed because the model doesnt have default values
    // and as we are using a bufferedProperty it's not accessible
    // in any other way
    next(() => {
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
    });
  }

  get hasQuery() {
    let modelQuery = this.model.get("query");
    let bufferedQuery = this.buffered.get("query");

    if (bufferedQuery) {
      return bufferedQuery.trim().length > 0;
    }
    return modelQuery && modelQuery.trim().length > 0;
  }

  get textCustomizationPrefix() {
    return `badges.${this.model.i18n_name}.`;
  }

  // FIXME: Remove observer
  @observes("model.id")
  _resetSaving() {
    this.saving = false;
    this.savingStatus = "";
  }

  showIconSelector() {
    this.selectedGraphicType = ICON;
  }

  showImageUploader() {
    this.selectedGraphicType = IMAGE;
  }

  @action
  changeGraphicType(newType) {
    if (newType === IMAGE) {
      this.showImageUploader();
    } else if (newType === ICON) {
      this.showIconSelector();
    } else {
      throw new Error(`Unknown badge graphic type "${newType}"`);
    }
  }

  @action
  setImage(upload) {
    this.buffered.set("image_upload_id", upload.id);
    this.buffered.set("image_url", getURL(upload.url));
  }

  @action
  removeImage() {
    this.buffered.set("image_upload_id", null);
    this.buffered.set("image_url", null);
  }

  @action
  showPreview(badge, explain, event) {
    event?.preventDefault();
    this.send("preview", badge, explain);
  }

  @action
  save() {
    if (!this.saving) {
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

      if (this.buffered.get("system")) {
        let protectedFields = this.protectedSystemFields || [];
        fields = fields.filter((f) => !protectedFields.includes(f));
      }

      this.saving = true;
      this.savingStatus = I18n.t("saving");

      const boolFields = [
        "allow_title",
        "multiple_grant",
        "listable",
        "auto_revoke",
        "enabled",
        "show_posts",
        "target_posts",
      ];

      const data = {};
      const buffered = this.buffered;
      fields.forEach(function (field) {
        let d = buffered.get(field);
        if (boolFields.includes(field)) {
          d = !!d;
        }
        data[field] = d;
      });

      const newBadge = !this.id;
      const model = this.model;
      this.model
        .save(data)
        .then(() => {
          if (newBadge) {
            const adminBadges = this.get("adminBadges.model");
            if (!adminBadges.includes(model)) {
              adminBadges.pushObject(model);
            }
            this.transitionToRoute("adminBadges.show", model.get("id"));
          } else {
            this.commitBuffer();
            this.savingStatus = I18n.t("saved");
          }
        })
        .catch(popupAjaxError)
        .finally(() => {
          this.saving = false;
          this.savingStatus = "";
        });
    }
  }

  @action
  destroyBadge() {
    const adminBadges = this.adminBadges.model;
    const model = this.model;

    if (!model?.get("id")) {
      this.router.transitionTo("adminBadges.index");
      return;
    }

    return this.dialog.yesNoConfirm({
      message: I18n.t("admin.badges.delete_confirm"),
      didConfirm: () => {
        model
          .destroy()
          .then(() => {
            adminBadges.removeObject(model);
            this.transitionToRoute("adminBadges.index");
          })
          .catch(() => {
            this.dialog.alert(I18n.t("generic_error"));
          });
      },
    });
  }

  @action
  toggleBadge() {
    const originalState = this.buffered.get("enabled");
    const newState = !this.buffered.get("enabled");

    this.buffered.set("enabled", newState);
    this.model.save({ enabled: newState }).catch((error) => {
      this.buffered.set("enabled", originalState);
      return popupAjaxError(error);
    });
  }
}
