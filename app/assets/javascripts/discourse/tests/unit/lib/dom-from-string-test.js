import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import domFromString from "discourse-common/lib/dom-from-string";

module("Unit | Utility | domFromString", function (hooks) {
  setupTest(hooks);

  test("constructing DOM node from a string", function (assert) {
    const node = domFromString(
      '<div class="foo">foo</div><div class="boo">boo</div>'
    );
    assert.dom(node[0]).hasClass("foo");
    assert.dom(node[1]).hasClass("boo");
  });
});
