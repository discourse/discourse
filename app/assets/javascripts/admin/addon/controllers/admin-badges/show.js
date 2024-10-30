import { cached, tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import { action, getProperties } from "@ember/object";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";
import { isNone } from "@ember/utils";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import getURL from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";
import BadgePreviewModal from "../../components/modal/badge-preview";

const FORM_FIELDS = [
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
  "image_url",
  "query",
  "badge_grouping_id",
  "trigger",
  "badge_type_id",
  "post_header",
];

export default class AdminBadgesShowController extends Controller {
  @service router;
  @service toasts;
  @service dialog;
  @service modal;

  @controller adminBadges;

  @tracked model;
  @tracked previewLoading = false;
  @tracked selectedGraphicType = null;
  @tracked userBadges;
  @tracked userBadgesAll;

  @alias("model.listable") listable;
  @alias("model.show_posts") showPosts;

  @cached
  get formData() {
    const data = getProperties(this.model, ...FORM_FIELDS);

    if (data.icon === "") {
      data.icon = undefined;
    }

    return data;
  }

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

  @discourseComputed("listable", "showPosts")
  showPostHeaderTooltip(listable, showPosts) {
    // We don't need to show the tooltip on system badges, since the other options are disabled
    return (!listable || !showPosts) && !this.model.system;
  }

  @discourseComputed("listable", "showPosts")
  disableBadgeOnPosts(listable, showPosts) {
    return !listable || !showPosts;
  }

  @action
  onSetListable(value) {
    this.listable = value;
  }

  @action
  onSetShowPosts(value) {
    this.showPosts = value;
  }

  setup() {
    // this is needed because the model doesnt have default values
    // Using `set` here isn't ideal, but we don't know that tracking is set up on the model yet.
    if (this.model) {
      if (isNone(this.model.badge_type_id)) {
        this.model.set("badge_type_id", this.badgeTypes?.[0]?.id);
      }

      if (isNone(this.model.badge_grouping_id)) {
        this.model.set("badge_grouping_id", this.badgeGroupings?.[0]?.id);
      }

      if (isNone(this.model.trigger)) {
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
      set("icon", null);
    } else {
      set("image_upload_id", "");
      set("image_url", "");
    }
  }

  @action
  onSetIcon(value, { set }) {
    set("icon", value);
    set("image_upload_id", "");
    set("image_url", "");
  }

  @action
  showPreview(badge, explain, event) {
    event?.preventDefault();
    this.preview(badge, explain);
  }

  @action
  validateForm(data, { addError, removeError }) {
    if (!data.icon && !data.image_url) {
      addError("icon", {
        title: "Icon",
        message: I18n.t("admin.badges.icon_or_image"),
      });
      addError("image_url", {
        title: "Image",
        message: I18n.t("admin.badges.icon_or_image"),
      });
    } else {
      removeError("image_url");
      removeError("icon");
    }
  }

  @action
  async preview(badge, explain) {
    try {
      this.previewLoading = true;
      const model = await ajax("/admin/badges/preview.json", {
        type: "POST",
        data: {
          sql: badge.query,
          target_posts: !!badge.target_posts,
          trigger: badge.trigger,
          explain,
        },
      });

      this.modal.show(BadgePreviewModal, { model: { badge: model } });
    } catch (e) {
      // eslint-disable-next-line no-console
      console.error(e);
      this.dialog.alert("Network error");
    } finally {
      this.previewLoading = false;
    }
  }

  @action
  async handleSubmit(formData) {
    let fields = FORM_FIELDS;

    if (formData.system) {
      const protectedFields = this.protectedSystemFields || [];
      fields = fields.filter((f) => !protectedFields.includes(f));
    }

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
    }
  }

  @action
  registerApi(api) {
    this.formApi = api;
  }

  @action
  async handleDelete() {
    if (!this.model?.id) {
      return this.router.transitionTo("adminBadges.index");
    }

    return this.dialog.yesNoConfirm({
      message: I18n.t("admin.badges.delete_confirm"),
      didConfirm: async () => {
        try {
          await this.formApi.reset();
          await this.model.destroy();
          this.adminBadges.model.removeObject(this.model);
          this.router.transitionTo("adminBadges.index");
        } catch {
          this.dialog.alert(I18n.t("generic_error"));
        }
      },
    });
  }
}
