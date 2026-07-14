import EmberObject from "@ember/object";
import { ajax } from "discourse/lib/ajax";

const GENERAL_ATTRIBUTES = [
  "updated_at",
  "discourse_updated_at",
  "release_notes_link",
];

export default class AdminDashboard extends EmberObject {
  static async fetch({ startDate, endDate, version } = {}) {
    const data = {};
    if (startDate) {
      data.start_date = moment(startDate).format("YYYY-MM-DD");
    }
    if (endDate) {
      data.end_date = moment(endDate).format("YYYY-MM-DD");
    }
    if (version) {
      data.version = version;
    }

    const json = await ajax("/admin/dashboard.json", { data });
    const model = AdminDashboard.create();

    model.setProperties({
      version_check: json.version_check,
      sections: json.sections,
      configuration: json.configuration,
      problems: json.problems,
    });

    return model;
  }

  static async fetchGeneral() {
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
  }

  static async fetchProblems() {
    const json = await ajax("/admin/dashboard/problems.json", { type: "POST" });
    const model = AdminDashboard.create(json);

    model.set("loaded", true);

    return model;
  }
}
