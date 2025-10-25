import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";

export default class TagGroupsNewController extends Controller {
  @service router;
  @controller tagGroups;

  @action
  onSave() {
    this.tagGroups.model.content.push(this.model);

    this.router.transitionTo("tagGroups.index");
  }
}
