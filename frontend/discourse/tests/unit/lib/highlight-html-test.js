import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import highlightHTML from "discourse/lib/highlight-html";

module("Unit | Utility | highlight-html", function (hooks) {
  setupTest(hooks);

  test("massive search string", function (assert) {
    const string = "a".repeat(32768);
    const elem = document.createElement("span");
    elem.innerHTML = string;
    const highlighted = highlightHTML(elem, string);
    assert.strictEqual(
      highlighted.innerHTML,
      string,
      "it should successfully bail when the string is too massive to highlight"
    );
  });
});
