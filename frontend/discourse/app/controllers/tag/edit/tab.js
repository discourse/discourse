import { tracked } from "@glimmer/tracking";
import Controller, { inject as controller } from "@ember/controller";

export default class TagEditTabController extends Controller {
  @controller("tag.edit") parentController;

  /** @type {{ tag_slug: string, tag_id: string } | null} */
  @tracked parentParams = null;

  get selectedTab() {
    return this.parentController.selectedTab;
  }
}
