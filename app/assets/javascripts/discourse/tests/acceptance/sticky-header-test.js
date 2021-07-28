import { acceptance, exists } from "discourse/tests/helpers/qunit-helpers";
import { visit } from "@ember/test-helpers";
import { test } from "qunit";

// in core, we add the `docked` class to the body tag to maintain compatibility
// with existing themes. We can't use the body tag in qunit because it doesn't
// exist. So, we approximate the behavior by adding the class to `#main-outlet`
// which does exist.

const scrollDown = () => {
  document.getElementById("ember-testing-container").scrollTop = 1;
  document.querySelector("#main-outlet").classList.add("docked-test");
};

const scrollToTop = () => {
  document.getElementById("ember-testing-container").scrollTop = 0;
  document.querySelector("#main-outlet").classList.remove("docked-test");
};

acceptance("sticky header check", function () {
  test("adds docked class to body when header is sticky", async function (assert) {
    await visit("/latest");

    assert.ok(
      exists(".header-dock-anchor"),
      "it adds the header scroll anchor div"
    );

    assert.notOk(
      exists("#main-outlet.docked-test"),
      "dock class is not added by default"
    );

    scrollDown();

    assert.ok(
      exists("#main-outlet.docked-test"),
      "dock class is added after scroll"
    );

    scrollToTop();

    assert.notOk(
      exists("#main-outlet.docked-test"),
      "dock class is removed after scrolling back to top"
    );
  });
});
