import { computed } from "@ember/object";
import getURL from "discourse/lib/get-url";
import RestModel from "discourse/models/rest";

export default class Query extends RestModel {
  static updatePropertyNames = [
    "name",
    "description",
    "sql",
    "user_id",
    "created_at",
    "group_ids",
    "last_run_at",
  ];

  params = {};

  constructor() {
    super(...arguments);
    this.param_info?.resetParams();
  }

  get downloadUrl() {
    return getURL(
      `/admin/plugins/discourse-data-explorer/queries/${this.id}.json?export=1`
    );
  }

  @computed("param_info", "updating")
  get hasParams() {
    // When saving, we need to refresh the param-input component to clean up the old key
    return this.param_info.length && !this.updating;
  }

  beforeUpdate() {
    this.set("updating", true);
  }

  afterUpdate() {
    this.set("updating", false);
  }

  resetParams() {
    const newParams = {};
    const oldParams = this.params;
    this.param_info.forEach((pinfo) => {
      const name = pinfo.identifier;
      if (oldParams[pinfo.identifier]) {
        newParams[name] = oldParams[name];
      } else if (pinfo["default"] !== null) {
        newParams[name] = pinfo["default"];
      } else if (pinfo["type"] === "boolean") {
        newParams[name] = "false";
      } else if (pinfo["type"] === "user_id") {
        newParams[name] = null;
      } else if (pinfo["type"] === "user_list") {
        newParams[name] = null;
      } else if (pinfo["type"] === "group_list") {
        newParams[name] = null;
      } else {
        newParams[name] = "";
      }
    });
    this.params = newParams;
  }

  updateProperties() {
    const props = this.getProperties(Query.updatePropertyNames);
    if (this.destroyed) {
      props.id = this.id;
    }
    return props;
  }

  createProperties() {
    if (this.sql) {
      // Importing
      return this.updateProperties();
    }
    return this.getProperties("name");
  }
}
