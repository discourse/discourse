import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class TagGroupsEditController extends Controller {
  @service router;
  @controller tagGroups;

  @action
  onDestroy() {
    const tagGroups = this.tagGroups.model;
    tagGroups.removeObject(this.model);

    this.router.transitionTo("tagGroups.index");
  }
}
