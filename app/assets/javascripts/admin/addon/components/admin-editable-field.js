import { tagName } from "@ember-decorators/component";
import Component from "@ember/component";
import { action } from "@ember/object";

@tagName("")
export default class AdminEditableField extends Component {
  buffer = "";
  editing = false;

  init() {
    super.init(...arguments);
    this.set("editing", false);
  }

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
