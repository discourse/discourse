import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";
import EmberObject, { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedObject } from "@ember-compat/tracked-built-ins";
import { observes } from "@ember-decorators/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";
import Preview from "../components/modal/preview";

export default class adminPluginsHouseAdsShow extends Controller {
  @service router;
  @service modal;

  @controller("adminPlugins.houseAds") houseAdsController;

  @tracked selectedCategories = [];
  @tracked selectedGroups = [];
  @tracked saving = false;
  @tracked savingStatus = "";
  @tracked buffered;

  @observes("model")
  modelChanged() {
    this.buffered = new TrackedObject({ ...this.model });
    this.selectedCategories = this.model.categories || [];
    this.selectedGroups = this.model.group_ids || [];
  }

  get disabledSave() {
    for (const key in this.buffered) {
      // we don't want to compare the categories array
      if (key !== "categories" && this.buffered[key] !== this.model[key]) {
        return false;
      }
    }
    return true;
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
      data.category_ids = this.buffered.category_ids;
      data.group_ids = this.buffered.group_ids;
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
            houseAds.pushObject(EmberObject.create(this.buffered));
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
    this.buffered.category_ids = categoryArray.map((c) => c.id);
    this.setCategoriesForBuffered();
  }

  @action
  setGroupIds(groupIds) {
    this.selectedGroups = groupIds;
    this.buffered.group_ids = groupIds.map((id) => id);
  }

  @action
  cancel() {
    this.buffered = new TrackedObject({ ...this.model });
    this.selectedCategories = this.model.categories || [];
    this.selectedGroups = this.model.group_ids || [];
    this.setCategoriesForBuffered();
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
      this.houseAdsController.model.removeObject(
        this.houseAdsController.model.findBy("id", this.buffered.id)
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

  setCategoriesForBuffered() {
    // we need to fetch the categories because the serializer is not being used
    // to attach the category object to the house ads
    this.buffered.categories = this.buffered.category_ids
      ? this.buffered.category_ids.map((categoryId) =>
          Category.findById(categoryId)
        )
      : [];
  }
}
