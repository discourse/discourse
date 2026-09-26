import Controller from "@ember/controller";
import { action } from "@ember/object";
import { service } from "discourse/lib/service";

export default class TagGroupsController extends Controller {
  @service router;

  @action
  newTagGroup() {
    this.router.transitionTo("tagGroups.new");
  }
}
