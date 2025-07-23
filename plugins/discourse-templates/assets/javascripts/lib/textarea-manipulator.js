import EmberObject from "@ember/object";
import { setOwner } from "@ember/application";
import TextareaTextManipulation from "discourse/mixins/textarea-text-manipulation";

export default class TextareaManipulator extends EmberObject.extend(
  TextareaTextManipulation
) {
  constructor(owner, textarea) {
    super(...arguments);
    setOwner(this, owner);

    this._textarea = textarea;
    this.element = this._textarea;
    this.ready = true;

    this.init();
  }

  addBlock(text) {
    this._addBlock(this.getSelected(), text);
  }
}
