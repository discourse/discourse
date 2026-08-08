import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { setupComposerPosition } from "discourse/lib/composer/composer-position";

module(
  "Unit | Lib | composer-position | selectionTouchmoveGuard",
  function (hooks) {
    setupTest(hooks);

    hooks.beforeEach(function () {
      const html = document.documentElement;
      // engages the scroll lock without needing the full composer DOM
      html.classList.add("ios-device");

      this.editor = document.createElement("div");
      this.editor.contentEditable = "true";
      this.editor.tabIndex = 0;
      this.editor.textContent = "some editor text";
      document.getElementById("ember-testing").appendChild(this.editor);
      this.editor.focus();

      this.teardownComposerPosition = setupComposerPosition(this.editor);
    });

    hooks.afterEach(function () {
      this.teardownComposerPosition();
      window.getSelection().removeAllRanges();
      this.editor.remove();
      document.documentElement.classList.remove("ios-device");
    });

    function dispatchTouchMove(target) {
      const touch = new Touch({
        identifier: 1,
        target,
        clientX: 10,
        clientY: 10,
      });
      target.dispatchEvent(
        new TouchEvent("touchmove", {
          bubbles: true,
          cancelable: true,
          touches: [touch],
          targetTouches: [touch],
          changedTouches: [touch],
        })
      );
    }

    test("stops touchmove for other listeners while the DOM selection is non-collapsed", function (assert) {
      window.getSelection().selectAllChildren(this.editor);

      let seen = false;
      const probe = () => (seen = true);
      this.editor.addEventListener("touchmove", probe);

      dispatchTouchMove(this.editor);
      assert.false(seen, "selection-handle drags bypass the scroll lock");

      window.getSelection().removeAllRanges();
      dispatchTouchMove(this.editor);
      assert.true(seen, "without a selection the event propagates");

      this.editor.removeEventListener("touchmove", probe);
    });

    test("a selection outside the editor keeps the scroll lock engaged", function (assert) {
      const outside = document.createElement("div");
      outside.textContent = "outside text";
      document.getElementById("ember-testing").appendChild(outside);
      window.getSelection().selectAllChildren(outside);

      let seen = false;
      const probe = () => (seen = true);
      this.editor.addEventListener("touchmove", probe);

      dispatchTouchMove(this.editor);
      assert.true(seen);

      this.editor.removeEventListener("touchmove", probe);
      outside.remove();
    });
  }
);
