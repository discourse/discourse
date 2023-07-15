import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { tracked } from "@glimmer/tracking";

export default class extends Controller {
  @controller discovery;

  @tracked q = "";

  queryParams = ["q"];

  @action
  updateTopicsListQueryParams(queryString) {
    this.q = queryString;
  }
}
