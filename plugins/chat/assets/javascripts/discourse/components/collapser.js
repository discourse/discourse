import Component from "@ember/component";
import { action } from "@ember/object";
import { tagName } from "@ember-decorators/component";

@tagName("")
export default class Collapser extends Component {
  collapsed = false;
  header = null;
  onToggle = null;

  @action
  open() {
    this.set("collapsed", false);
    this.onToggle?.(false);
  }

  @action
  close() {
    this.set("collapsed", true);
    this.onToggle?.(true);
  }
}
