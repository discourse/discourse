import { settled } from "@ember/test-helpers";
import { setupTest } from "ember-qunit";
import { module, test } from "qunit";
import sinon from "sinon";
import { USER_OPTION_COMPOSITION_MODES } from "discourse/lib/constants";
import Composer from "discourse/models/composer";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
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

  test("importQuote quotes the first post of a mega topic", async function (assert) {
    setComposerModel(this);
    const topic = this.owner
      .lookup("service:store")
      .createRecord("topic", { id: 280 });
    topic.postStream.isMegaTopic = true;
    topic.postStream.stream = [9001];
    this.composer.set("topic", topic);
    pretender.get("/posts/by_number/280/1", () =>
      response({ id: 398, post_number: 1, topic_id: 280 })
    );
    const toolbarEvent = { addText: sinon.spy() };

    await this.composer.importQuote(toolbarEvent);
    await settled();

    assert.true(
      toolbarEvent.addText.calledOnceWith(
        sinon.match("Any plans to support localization")
      )
    );
  });

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

  test("predicts no preview for the rich editor before it mounts", function (assert) {
    this.currentUser.set(
      "user_option.composition_mode",
      USER_OPTION_COMPOSITION_MODES.rich
    );
    assert.false(this.composer.allowPreview, "the rich editor has no preview");
    assert.false(
      this.composer.isPreviewVisible,
      "the rich editor does not reserve preview space before it mounts"
    );
  });

  test("closing clears the mounted editor override", function (assert) {
    setComposerModel(this);
    this.composer.set("allowPreview", false);

    assert.false(
      this.composer.allowPreview,
      "the mounted editor can override the prediction for this composer"
    );
    this.composer.close();

    assert.true(
      this.composer.allowPreview,
      "the next composer uses the predicted markdown mode"
    );
  });
});
