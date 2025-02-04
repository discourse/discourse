import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import BulkSelectHelper from "discourse/lib/bulk-select-helper";

export default class extends Controller {
  @tracked q = "";

  queryParams = ["q"];
  bulkSelectHelper = new BulkSelectHelper(this);

  get canBulkSelect() {
    return this.currentUser?.canManageTopic;
  }

  @action
  updateTopicsListQueryParams(queryString) {
    this.q = queryString;
  }
}
