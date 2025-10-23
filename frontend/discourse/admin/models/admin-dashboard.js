import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

const GENERAL_ATTRIBUTES = [
  "updated_at",
  "discourse_updated_at",
  "release_notes_link",
];

export default class AdminDashboard extends EmberObject {
  static fetch() {
    return ajax("/admin/dashboard.json").then((json) => {
      const model = AdminDashboard.create();
      model.setProperties({
        version_check: json.version_check,
      });

      return model;
    });
  }

  static fetchGeneral() {
    return ajax("/admin/dashboard/general.json").then((json) => {
      const model = AdminDashboard.create();

      const attributes = {};
      GENERAL_ATTRIBUTES.forEach((a) => (attributes[a] = json[a]));

      model.setProperties({
        reports: json.reports,
        attributes,
        loaded: true,
      });

      return model;
    });
  }

  static fetchProblems() {
    return ajax("/admin/dashboard/problems.json").then((json) => {
      const model = AdminDashboard.create(json);
      model.set("loaded", true);
      return model;
    });
  }
}
