import Controller, { inject as controller } from "@ember/controller";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { removeValueFromArray } from "discourse/lib/array-tools";

export default class TagGroupsEditController extends Controller {
  @service router;
  @controller tagGroups;

  @action
  onDestroy() {
    removeValueFromArray(this.tagGroups.model.content, this.model);

    this.router.transitionTo("tagGroups.index");
  }
}
