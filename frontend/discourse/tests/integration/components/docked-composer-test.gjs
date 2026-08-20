import { getOwner } from "@ember/owner";
import { fillIn, render, triggerKeyEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import DockedComposer from "discourse/components/docked-composer";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";

module("Integration | Component | DockedComposer", function (hooks) {
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

  test("honors the meta_enter send_shortcut user option", async function (assert) {
    const currentUser = getOwner(this).lookup("service:current-user");
    currentUser.set("user_option.send_shortcut", "meta_enter");

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
          @draftKey="test-send-shortcut-option"
        />
      </template>
    );

    await fillIn(".d-editor-input", "hello");
    await triggerKeyEvent(".d-editor-input", "keydown", "Enter");
    assert.false(
      submitted,
      "bare Enter does not submit for meta_enter send_shortcut"
    );

    await triggerKeyEvent(".d-editor-input", "keydown", "Enter", {
      metaKey: true,
    });
    assert.true(submitted, "Meta+Enter submits for meta_enter send_shortcut");
  });

  test("submits on Ctrl+Enter for the meta_enter send_shortcut user option", async function (assert) {
    const currentUser = getOwner(this).lookup("service:current-user");
    currentUser.set("user_option.send_shortcut", "meta_enter");

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
          @draftKey="test-send-shortcut-ctrl"
        />
      </template>
    );

    await fillIn(".d-editor-input", "hello");
    await triggerKeyEvent(".d-editor-input", "keydown", "Enter", {
      ctrlKey: true,
    });

    assert.true(submitted, "Ctrl+Enter submits for meta_enter send_shortcut");
  });

  test("explicit @submitOnEnter overrides the send_shortcut user option", async function (assert) {
    const currentUser = getOwner(this).lookup("service:current-user");
    currentUser.set("user_option.send_shortcut", "meta_enter");

    let submitted = false;
    const handleSubmit = async () => {
      submitted = true;
      return { ok: true };
    };

    await render(
      <template>
        <DockedComposer
          @onSubmit={{handleSubmit}}
          @submitOnEnter={{true}}
          @composerEvents={{false}}
          @draftKey="test-send-shortcut-override"
        />
      </template>
    );

    await fillIn(".d-editor-input", "hello");
    await triggerKeyEvent(".d-editor-input", "keydown", "Enter");

    assert.true(
      submitted,
      "bare Enter submits when @submitOnEnter is explicitly true"
    );
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

  test("auto resize does not render the manual resize handle", async function (assert) {
    await render(
      <template>
        <DockedComposer
          @autoResize={{true}}
          @resizable={{true}}
          @maxResizeOffset={{200}}
          @composerEvents={{false}}
          @draftKey="test-auto-resize"
        />
      </template>
    );

    assert.dom(".docked-composer").hasClass("docked-composer--auto-resize");
    assert.dom(".docked-composer__resize-handle").doesNotExist();
    assert.strictEqual(
      document
        .querySelector(".docked-composer")
        .style.getPropertyValue("--docked-composer-max-resize-offset"),
      "200px"
    );
  });

  test("keyboard End key respects @maxResizeOffset when provided", async function (assert) {
    await render(
      <template>
        <DockedComposer
          @resizable={{true}}
          @maxResizeOffset={{200}}
          @composerEvents={{false}}
          @draftKey="test-resize-max"
        />
      </template>
    );

    await triggerKeyEvent(".docked-composer__resize-handle", "keydown", "End");

    assert.strictEqual(
      document
        .querySelector(".docked-composer__resize-handle")
        .getAttribute("aria-valuenow"),
      "200",
      "End key snaps to @maxResizeOffset, not the default 400"
    );
  });

  test("keyboard End key defaults to 400 when @maxResizeOffset is not provided", async function (assert) {
    await render(
      <template>
        <DockedComposer
          @resizable={{true}}
          @composerEvents={{false}}
          @draftKey="test-resize-default"
        />
      </template>
    );

    await triggerKeyEvent(".docked-composer__resize-handle", "keydown", "End");

    assert.strictEqual(
      document
        .querySelector(".docked-composer__resize-handle")
        .getAttribute("aria-valuenow"),
      "400",
      "End key defaults to 400 when no @maxResizeOffset"
    );
  });

  test("the arrow keys grow the composer upward and shrink it back", async function (assert) {
    await render(
      <template>
        <DockedComposer
          @resizable={{true}}
          @composerEvents={{false}}
          @draftKey="test-resize-arrows"
        />
      </template>
    );

    const handle = document.querySelector(".docked-composer__resize-handle");
    const offset = () =>
      document
        .querySelector(".docked-composer")
        .style.getPropertyValue("--docked-composer-drag-offset");

    await triggerKeyEvent(handle, "keydown", "ArrowUp");
    assert.dom(handle).hasAttribute("aria-valuenow", "16");
    assert.strictEqual(
      offset(),
      "16px",
      "dragging the handle up with the keyboard grows the composer"
    );

    await triggerKeyEvent(handle, "keydown", "ArrowDown");
    assert.dom(handle).hasAttribute("aria-valuenow", "0");
    assert.strictEqual(offset(), "0px", "ArrowDown shrinks it back");

    await triggerKeyEvent(handle, "keydown", "ArrowDown");
    assert
      .dom(handle)
      .hasAttribute(
        "aria-valuenow",
        "0",
        "it cannot shrink past its resting size"
      );
  });

  test("Home returns the composer to its resting size", async function (assert) {
    await render(
      <template>
        <DockedComposer
          @resizable={{true}}
          @composerEvents={{false}}
          @draftKey="test-resize-home"
        />
      </template>
    );

    const handle = document.querySelector(".docked-composer__resize-handle");

    await triggerKeyEvent(handle, "keydown", "End");
    assert.dom(handle).hasAttribute("aria-valuenow", "400");

    await triggerKeyEvent(handle, "keydown", "Home");
    assert.dom(handle).hasAttribute("aria-valuenow", "0");
    assert.strictEqual(
      document
        .querySelector(".docked-composer")
        .style.getPropertyValue("--docked-composer-drag-offset"),
      "0px",
      "the rendered offset follows"
    );
  });
});
