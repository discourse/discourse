import { discourseModule } from "discourse/tests/helpers/qunit-helpers";
import { test } from "qunit";
import domFromString from "discourse-common/lib/dom-from-string";

discourseModule("Unit | Utility | domFromString", function () {
  test("constructing DOM node from a string", function (assert) {
    const node = domFromString('<div class="foo">foo</div>');
    assert.ok(node.classList.contains("foo"));
  });
});
