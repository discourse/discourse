import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";

const GENERAL_ATTRIBUTES = [
  "updated_at",
  "discourse_updated_at",
  "release_notes_link",
];

export default class AdminDashboard extends EmberObject {
  static async fetch() {
    try {
      const json = await ajax("/admin/dashboard.json");
      const model = AdminDashboard.create();

      model.setProperties({
        version_check: json.version_check,
      });

      return model;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  static async fetchGeneral() {
    try {
      const json = await ajax("/admin/dashboard/general.json");
      const model = AdminDashboard.create();

      const attributes = {};
      GENERAL_ATTRIBUTES.forEach((a) => (attributes[a] = json[a]));

      model.setProperties({
        reports: json.reports,
        attributes,
        loaded: true,
      });

      return model;
    } catch (error) {
      popupAjaxError(error);
    }
  }

  static async fetchProblems() {
    try {
      const json = await ajax("/admin/dashboard/problems.json", {
        type: "POST",
      });
      const model = AdminDashboard.create(json);

      model.set("loaded", true);

      return model;
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
