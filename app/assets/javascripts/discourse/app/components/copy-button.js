import Component from "@ember/component";
import { action } from "@ember/object";
import copyText from "discourse/lib/copy-text";

export default Component.extend({
  tagName: "",

  @action
  copy() {
    const $copyRange = $('<p id="copy-range"></p>');
    $copyRange.html(this.content);
    $(document.body).append($copyRange);
    copyText(this.content, $copyRange[0]);
    $copyRange.remove();
  },
});
