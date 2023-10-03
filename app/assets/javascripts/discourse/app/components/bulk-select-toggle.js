import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/application";

export default class BulkSelectToggle extends Component {
  @action
  toggleBulkSelect() {
    const controller = getOwner(this).lookup(
      `controller:${this.args.parentController}`
    );
    const helper = controller.bulkSelectHelper;
    helper.clear();
    helper.bulkSelectEnabled = !helper.bulkSelectEnabled;
  }
}
