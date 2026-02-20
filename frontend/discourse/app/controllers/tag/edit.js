import { tracked } from "@glimmer/tracking";
import Controller from "@ember/controller";

export default class TagEditController extends Controller {
  @tracked selectedTab = "general";
  @tracked parentParams = null;
}
