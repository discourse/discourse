import Component from "@glimmer/component";
import { action } from "@ember/object";

export default class BulkSelectToggle extends Component {
  @action
  toggleBulkSelect() {
    this.args.bulkSelectHelper.toggleBulkSelect();
  }
}
