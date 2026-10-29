import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";
import { action } from "@ember/object";

export default class extends Controller {
  @tracked changeNamesFilter = "";
  @tracked sort = null;
  queryParams = [
    {
      changeNamesFilter: { replace: true },
      sort: { replace: true },
    },
  ];

  @action
  clearChangeNamesFilter() {
    this.changeNamesFilter = "";
  }

  @action
  updateSort(sort) {
    this.sort = sort;
  }
}
