import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import {
  setCompositionMode,
  toggledCompositionMode,
} from "discourse/lib/composer/composition-mode";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Lib | composer composition mode", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.user = logIn(this.owner);
  });

  test("toggles between the two modes", function (assert) {
    this.user.set(
      "user_option.composition_mode",
      USER_OPTION_COMPOSITION_MODES.rich
    );
    assert.strictEqual(
      toggledCompositionMode(this.user),
      USER_OPTION_COMPOSITION_MODES.markdown
    );

    this.user.set(
      "user_option.composition_mode",
      USER_OPTION_COMPOSITION_MODES.markdown
    );
    assert.strictEqual(
      toggledCompositionMode(this.user),
      USER_OPTION_COMPOSITION_MODES.rich
    );
  });

  test("applies right away and saves once for quick toggles", async function (assert) {
    const save = sinon.stub(this.user, "save").resolves();

    setCompositionMode(this.user, USER_OPTION_COMPOSITION_MODES.markdown);
    assert.strictEqual(
      this.user.user_option.composition_mode,
      USER_OPTION_COMPOSITION_MODES.markdown
    );

    setCompositionMode(this.user, USER_OPTION_COMPOSITION_MODES.rich);
    await settled();

    assert.true(save.calledOnceWith(["composition_mode"]));
    assert.strictEqual(
      this.user.user_option.composition_mode,
      USER_OPTION_COMPOSITION_MODES.rich
    );
  });
});
