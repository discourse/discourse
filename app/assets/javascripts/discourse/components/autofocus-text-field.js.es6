import { on } from "ember-addons/ember-computed-decorators";

export default Ember.TextField.extend({

  @on("didInsertElement")
  becomeFocused() {
    const input = this.get("element");
    input.focus();
    input.selectionStart = input.selectionEnd = input.value.length;
  }

});
