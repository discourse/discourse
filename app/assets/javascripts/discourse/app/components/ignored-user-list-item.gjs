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
<div class="ignored-user-list-item">
  <span class="ignored-user-name">{{this.item}}</span>
  <DButton
    @action={{fn (action "removeIgnoredUser") this.item}}
    @icon="xmark"
    class="remove-ignored-user no-text btn-icon"
  />
</div>