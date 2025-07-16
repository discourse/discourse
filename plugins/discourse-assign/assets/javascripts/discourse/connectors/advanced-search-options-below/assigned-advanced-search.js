import Component from "@ember/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { classNames } from "@ember-decorators/component";

@classNames("assigned-advanced-search")
export default class AssignedAdvancedSearch extends Component {
  static shouldRender(args, component) {
    return component.currentUser?.can_assign;
  }

  @service currentUser;

  @action
  onChangeAssigned(value) {
    this.outletArgs.onChangeSearchedTermField(
      "assigned",
      "updateSearchTermForAssignedUsername",
      value
    );
  }
}
