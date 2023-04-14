import Controller, { inject as controller } from "@ember/controller";

export default class extends Controller {
  @controller("discovery/filter") discoveryFilter;

  queryString = "";

  constructor() {
    super(...arguments);
    this.queryString = this.discoveryFilter.q;
  }
}
