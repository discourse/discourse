import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";

export default class BlogThemesNewController extends Controller {
  @tracked from = null;

  queryParams = ["from"];
}
