import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwnerWithFallback } from "discourse-common/lib/get-owner";

export default class BulkSelectToggle extends Component {
  @action
  toggleBulkSelect() {
    const controller = getOwnerWithFallback(this).lookup(
      `controller:${this.args.parentController}`
    );
    const helper = controller.bulkSelectHelper;
    helper.clear();
    helper.bulkSelectEnabled = !helper.bulkSelectEnabled;
  }
}
