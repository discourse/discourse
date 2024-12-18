import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class AdminAreaSettingsBaseController extends Controller {
  @tracked filter = "";
  queryParams = ["filter"];

  @action
  adminSettingsFilterChangedCallback(filter) {
    this.filter = filter;
  }
}
