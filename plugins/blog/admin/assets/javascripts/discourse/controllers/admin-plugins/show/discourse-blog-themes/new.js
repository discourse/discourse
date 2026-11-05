import Controller from "@ember/controller";

export default class BlogThemesNewController extends Controller {
  queryParams = ["from"];
  from = null;
}
