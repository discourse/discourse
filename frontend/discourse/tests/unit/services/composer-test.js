import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import Composer from "discourse/models/composer";
import { logIn } from "discourse/tests/helpers/qunit-helpers";

module("Unit | Service | composer", function (hooks) {
  setupTest(hooks);

  hooks.beforeEach(function () {
    this.currentUser = logIn(this.owner);
    this.currentUser.set(
      "user_option.composition_mode",
      USER_OPTION_COMPOSITION_MODES.markdown
    );
    this.composer = this.owner.lookup("service:composer");
    this.composer.showPreview = true;
  });

  function setComposerModel(context) {
    context.composer.set(
      "model",
      context.owner.lookup("service:store").createRecord("composer", {
        action: Composer.CREATE_TOPIC,
        composeState: Composer.OPEN,
      })
    );
  }

  test("predicts the markdown preview before a composer model exists", function (assert) {
    assert.true(
      this.composer.allowPreview,
      "markdown allows a preview even before opening"
    );
    assert.true(
      this.composer.isPreviewVisible,
      "the closed composer reserves its final preview width"
    );
  });

  test("predicts the markdown preview before the editor mounts", function (assert) {
    setComposerModel(this);

    assert.true(this.composer.allowPreview, "markdown allows a preview");
    assert.true(
      this.composer.isPreviewVisible,
      "the composer can use its final width before the editor mounts"
    );
  });

  test("predicts no preview for the rich editor before it mounts", function (assert) {
    this.currentUser.set(
      "user_option.composition_mode",
      USER_OPTION_COMPOSITION_MODES.rich
    );
    setComposerModel(this);

    assert.false(this.composer.allowPreview, "the rich editor has no preview");
    assert.false(
      this.composer.isPreviewVisible,
      "the rich editor does not reserve preview space before it mounts"
    );
  });

  test("the mounted editor can override the predicted preview", function (assert) {
    this.currentUser.set(
      "user_option.composition_mode",
      USER_OPTION_COMPOSITION_MODES.rich
    );
    setComposerModel(this);
    this.composer.set("allowPreview", true);

    assert.true(
      this.composer.isPreviewVisible,
      "the mounted editor can override the prediction"
    );
  });

  test("closing preserves the predicted markdown preview width", function (assert) {
    setComposerModel(this);
    this.composer.close();

    assert.false(this.composer.isOpen, "the composer is closed");
    assert.true(
      this.composer.isPreviewVisible,
      "the next opening does not need to expand the composer width"
    );
  });
});
