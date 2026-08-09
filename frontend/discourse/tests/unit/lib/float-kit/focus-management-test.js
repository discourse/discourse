import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import FocusManagement from "discourse/float-kit/components/d-sheet/focus-management";

module("Unit | Lib | float-kit | focus-management", function (hooks) {
  setupTest(hooks);

  test("present autofocus uses source-literal falsey behavior", function (assert) {
    const outside = document.createElement("button");
    const view = document.createElement("div");
    const inside = document.createElement("button");
    const controller = {
      id: "focus-sheet",
      onPresentAutoFocus: { focus: null },
      sheetRegistry: null,
      view,
    };

    view.tabIndex = -1;
    view.append(inside);
    document.querySelector("#qunit-fixture").append(outside, view);
    outside.focus();

    new FocusManagement(controller).executeAutoFocusOnPresent();

    assert.strictEqual(
      document.activeElement,
      outside,
      "an explicit null focus behavior leaves current focus unchanged"
    );
  });
});
