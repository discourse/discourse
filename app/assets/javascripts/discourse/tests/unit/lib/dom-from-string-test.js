import { module, test } from "qunit";
import domFromString from "discourse-common/lib/dom-from-string";
import { setupTest } from "ember-qunit";

module("Unit | Utility | domFromString", function (hooks) {
  setupTest(hooks);

  test("constructing DOM node from a string", function (assert) {
    const node = domFromString(
      '<div class="foo">foo</div><div class="boo">boo</div>'
    );
    assert.ok(node[0].classList.contains("foo"));
    assert.ok(node[1].classList.contains("boo"));
  });
});
