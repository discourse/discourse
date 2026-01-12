import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { observes } from "@ember-decorators/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { i18n } from "discourse-i18n";
import Preview from "../../../components/modal/preview";

export default class adminPluginsHouseAdsShow extends Controller {
  @service router;
  @service modal;
  @service siteSettings;

  @controller("adminPlugins.houseAds") houseAdsController;

  @tracked selectedCategories = [];
  @tracked selectedGroups = [];
  @tracked selectedRoutes = [];
  @tracked saving = false;
  @tracked savingStatus = "";
  @tracked buffered;

  @observes("model")
  modelChanged() {
    this.buffered = new TrackedObject({ ...this.model });
    this.selectedCategories = this.model.categories || [];
    this.selectedGroups = this.model.groups || [];
    this.selectedRoutes = this.model.routes || [];
  }

  get disabledSave() {
    for (const key in this.buffered) {
      if (this.buffered[key] !== this.model[key]) {
        return false;
      }
    }
    return true;
  }

  get routesEnabled() {
    return this.siteSettings.ad_plugin_routes_enabled;
  }

  @action
  async save() {
    if (!this.saving) {
      this.saving = true;
      this.savingStatus = i18n("saving");
      const data = {};
      const newRecord = !this.buffered.id;
      if (!newRecord) {
        data.id = this.buffered.id;
      }
      data.name = this.buffered.name;
      data.html = this.buffered.html;
      data.visible_to_logged_in_users =
        this.buffered.visible_to_logged_in_users;
      data.visible_to_anons = this.buffered.visible_to_anons;
      data.category_ids = this.buffered.categories
        ? this.buffered.categories.map((c) => c.id)
        : [];
      data.group_ids = this.buffered.groups
        ? this.buffered.groups.map((g) => g.id)
        : [];
      data.routes = this.buffered.routes || [];
      try {
        const ajaxData = await ajax(
          newRecord
            ? `/admin/plugins/pluginad/house_creatives`
            : `/admin/plugins/pluginad/house_creatives/${this.buffered.id}`,
          {
            type: newRecord ? "POST" : "PUT",
            data,
          }
        );
        this.savingStatus = i18n("saved");
        const houseAds = this.houseAdsController.model;
        if (newRecord) {
          this.buffered.id = ajaxData.house_ad.id;
          if (!houseAds.includes(this.buffered)) {
            houseAds.push(EmberObject.create(this.buffered));
          }
          this.router.transitionTo(
            "adminPlugins.houseAds.show",
            this.buffered.id
          );
        } else {
          houseAds
            .find((ad) => ad.id === this.buffered.id)
            .setProperties(this.buffered);
        }
      } catch (error) {
        popupAjaxError(error);
      } finally {
        this.set("model", this.buffered);
        this.saving = false;
        this.savingStatus = "";
      }
    }
  }

  @action
  setCategoryIds(categoryArray) {
    this.selectedCategories = categoryArray;
    this.buffered.categories = this.selectedCategories;
  }

  @action
  setGroupIds(groupIds) {
    this.selectedGroups = groupIds;
    this.buffered.groups = groupIds;
  }

  @action
  setRoutes(routes) {
    this.selectedRoutes = routes;
    this.buffered.routes = routes;
  }

  @action
  cancel() {
    this.buffered = new TrackedObject({ ...this.model });
    this.selectedCategories = this.model.categories || [];
    this.selectedGroups = this.model.groups || [];
  }

  @action
  async destroy() {
    if (!this.buffered.id) {
      this.router.transitionTo("adminPlugins.houseAds.index");
      return;
    }
    try {
      await ajax(
        `/admin/plugins/pluginad/house_creatives/${this.buffered.id}`,
        {
          type: "DELETE",
        }
      );
      removeValueFromArray(
        this.houseAdsController.model,
        this.houseAdsController.model.find(
          (item) => item.id === this.buffered.id
        )
      );
      this.router.transitionTo("adminPlugins.houseAds.index");
    } catch (error) {
      popupAjaxError(error);
    }
  }

  @action
  openPreview() {
    this.modal.show(Preview, {
      model: {
        html: this.buffered.html,
      },
    });
  }
}
