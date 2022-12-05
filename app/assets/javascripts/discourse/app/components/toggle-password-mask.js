import { action } from "@ember/object";
import Component from "@glimmer/component";
import { getOwner } from "discourse-common/lib/get-owner";

export default class TogglePasswordMask extends Component {
  @action
  togglePasswordMask(parentController) {
    const controller = getOwner(this).lookup(`controller:${parentController}`);
    const maskState = controller.get("maskPassword");
    return controller.set("maskPassword", !maskState);
  }
}
