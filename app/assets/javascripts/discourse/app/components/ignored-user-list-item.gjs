import Component from "@ember/component";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";

@tagName("div")
export default class IgnoredUserListItem extends Component {
  items = null;

  @action
  removeIgnoredUser(item) {
    this.onRemoveIgnoredUser(item);
  }
}
