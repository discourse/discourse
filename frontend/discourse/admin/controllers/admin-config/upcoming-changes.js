import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class extends Controller {
  @tracked changeNamesFilter = "";
  queryParams = [
    {
      changeNamesFilter: { replace: true },
    },
  ];

  @action
  clearChangeNamesFilter() {
    this.changeNamesFilter = "";
  }
}
