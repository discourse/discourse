import Service from "@ember/service";
import { click, render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import NewTopicButton from "discourse/blocks/builtin/new-topic-button";
import {
  DEBUG_CALLBACK,
  debugHooks,
} from "discourse/lib/blocks/-internals/debug-hooks";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

// `openNewTopic` is an `@action` (a getter-only binding), so it can't be
// reassigned on the real service — register a stub service instead and record
// the calls it receives.
class ComposerStub extends Service {
  openCalls = [];

  openNewTopic(opts) {
    this.openCalls.push(opts);
    return Promise.resolve();
  }
}

module("Integration | Blocks | new-topic-button", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    this.owner.unregister("service:composer");
    this.owner.register("service:composer", ComposerStub);
    this.composer = this.owner.lookup("service:composer");
  });

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
    debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, null);
  });

  test("renders a button and opens the composer with the configured tags and title", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: NewTopicButton,
          args: {
            label: "Ask a question",
            tags: ["question"],
            prefillTitle: "My question",
          },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".d-block-new-topic-button").exists("renders the button");
    assert
      .dom(".d-block-new-topic-button")
      .hasText("Ask a question", "renders the label");

    await click(".d-block-new-topic-button");

    assert.strictEqual(
      this.composer.openCalls.length,
      1,
      "opens the composer once on click"
    );
    assert.deepEqual(
      this.composer.openCalls[0].tags,
      ["question"],
      "passes the configured tags"
    );
    assert.strictEqual(
      this.composer.openCalls[0].title,
      "My question",
      "passes the prefilled title"
    );
  });

  test("stays inert in an editing/preview context", async function (assert) {
    debugHooks.setCallback(DEBUG_CALLBACK.EDIT_PRESENTATION, () => true);

    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: NewTopicButton,
          args: { label: "Ask a question", tags: ["question"] },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    await click(".d-block-new-topic-button");

    assert.strictEqual(
      this.composer.openCalls.length,
      0,
      "does not open the composer while editing"
    );
  });
});
