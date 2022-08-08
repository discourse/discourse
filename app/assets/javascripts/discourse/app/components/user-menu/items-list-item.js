import GlimmerComponent from "discourse/components/glimmer";
import { action } from "@ember/object";

export default class UserMenuItemsListItem extends GlimmerComponent {
  @action
  onClick() {
    return this.args.item.onClick();
  }
}
