import { fillIn, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import DockedComposer from "discourse/components/docked-composer";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | docked-composer", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/emojis/search-aliases.json", () => response([]));
  });

  test("submits on bare Enter by default", async function (assert) {
    let submitted = false;
    const handleSubmit = async () => {
      submitted = true;
      return { ok: true };
    };

    await render(
      <template>
        <DockedComposer
          @onSubmit={{handleSubmit}}
          @composerEvents={{false}}
          @draftKey="test-submit-enter"
        />
      </template>
    );

    await fillIn(".d-editor-input", "hello");
    await triggerKeyEvent(".d-editor-input", "keydown", "Enter");

    assert.true(submitted, "bare Enter submits when submitOnEnter is default");
  });

  test("does not submit on bare Enter when @submitOnEnter is false", async function (assert) {
    let submitted = false;
    const handleSubmit = async () => {
      submitted = true;
      return { ok: true };
    };

    await render(
      <template>
        <DockedComposer
          @onSubmit={{handleSubmit}}
          @submitOnEnter={{false}}
          @composerEvents={{false}}
          @draftKey="test-no-submit-enter"
        />
      </template>
    );

    await fillIn(".d-editor-input", "hello");
    await triggerKeyEvent(".d-editor-input", "keydown", "Enter");

    assert.false(
      submitted,
      "bare Enter does not submit when submitOnEnter is false"
    );
  });

  test("submits on Ctrl+Enter when @submitOnEnter is false", async function (assert) {
    let submitted = false;
    const handleSubmit = async () => {
      submitted = true;
      return { ok: true };
    };

    await render(
      <template>
        <DockedComposer
          @onSubmit={{handleSubmit}}
          @submitOnEnter={{false}}
          @composerEvents={{false}}
          @draftKey="test-ctrl-enter"
        />
      </template>
    );

    await fillIn(".d-editor-input", "hello");
    await triggerKeyEvent(".d-editor-input", "keydown", "Enter", {
      ctrlKey: true,
    });

    assert.true(submitted, "Ctrl+Enter submits when submitOnEnter is false");
  });

  test("submits on Meta+Enter when @submitOnEnter is false", async function (assert) {
    let submitted = false;
    const handleSubmit = async () => {
      submitted = true;
      return { ok: true };
    };

    await render(
      <template>
        <DockedComposer
          @onSubmit={{handleSubmit}}
          @submitOnEnter={{false}}
          @composerEvents={{false}}
          @draftKey="test-meta-enter"
        />
      </template>
    );

    await fillIn(".d-editor-input", "hello");
    await triggerKeyEvent(".d-editor-input", "keydown", "Enter", {
      metaKey: true,
    });

    assert.true(submitted, "Meta+Enter submits when submitOnEnter is false");
  });
});
