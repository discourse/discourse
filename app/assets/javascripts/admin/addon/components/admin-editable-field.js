import Component from "@ember/component";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class AdminEditableField extends Component {
  buffer = "";
  editing = false;

  @action
  edit(event) {
    event?.preventDefault();
    this.set("buffer", this.value);
    this.toggleProperty("editing");
  }

  @action
  save() {
    // Action has to toggle 'editing' property.
    this.action(this.buffer);
  }
}
