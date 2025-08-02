import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class TagGroupsNewController extends Controller {
  @service router;
  @controller tagGroups;

  @action
  onSave() {
    const tagGroups = this.tagGroups.model;
    tagGroups.pushObject(this.model);

    this.router.transitionTo("tagGroups.index");
  }
}
