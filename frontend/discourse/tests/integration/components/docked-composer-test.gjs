import { getOwner } from "@ember/owner";
import {
  clearRender,
  click,
  fillIn,
  find,
  render,
  settled,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import DockedComposer from "discourse/components/docked-composer";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import pretender, { response } from "discourse/tests/helpers/create-pretender";
import { fakeTime } from "discourse/tests/helpers/qunit-helpers";

module("Integration | Component | DockedComposer", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    pretender.get("/emojis/search-aliases.json", () => response([]));
  });

  test("submits active typing time separately from time spent idle", async function (assert) {
    const clock = fakeTime("2026-11-16T00:00:00", null, true);
    let submission;
    const handleSubmit = (data) => {
      submission = data;
      return { ok: true };
    };

    try {
      await render(
        <template>
          <DockedComposer
            @composerEvents={{false}}
            @draftKey="test-typing-time"
            @onSubmit={{handleSubmit}}
          />
        </template>
      );

      clock.tick(10_000);
      await fillIn(".d-editor-input", "First");
      await fillIn(".d-editor-input", "First comment");
      await fillIn(".d-editor-input", "First comment complete");
      clock.tick(10_000);
      await click(".docked-composer__submit-btn");

      assert.strictEqual(
        submission.typingTime,
        300,
        "idle time does not count as typing"
      );
      assert.true(
        submission.composerTime >= 20_000,
        "open time includes idle time"
      );
    } finally {
      clock.restore();
    }
  });

  test("retains timing after a rejected submission and resets it after success", async function (assert) {
    const submissions = [];
    const handleSubmit = (data) => {
      submissions.push(data);
      return submissions.length > 1;
    };

    await render(
      <template>
        <DockedComposer
          @composerEvents={{false}}
          @draftKey="test-typing-retry"
          @onSubmit={{handleSubmit}}
        />
      </template>
    );

    await fillIn(".d-editor-input", "First comment");
    await click(".docked-composer__submit-btn");
    assert.strictEqual(
      submissions[0].typingTime,
      100,
      "the first attempt includes its typing time"
    );
    assert
      .dom(".d-editor-input")
      .hasValue("First comment", "rejected submission keeps the comment");
    await click(".docked-composer__submit-btn");
    assert.strictEqual(
      submissions[1].typingTime,
      submissions[0].typingTime,
      "retry keeps the recorded typing time"
    );

    await fillIn(".d-editor-input", "Second");
    await fillIn(".d-editor-input", "Second comment");
    await click(".docked-composer__submit-btn");
    assert.strictEqual(
      submissions[2].typingTime,
      200,
      "the next comment starts with fresh timing"
    );
  });

  test("replacing the text starts a fresh typing measurement", async function (assert) {
    let composerApi;
    let submission;
    const registerApi = (api) => {
      composerApi = api;
    };
    const handleSubmit = (data) => {
      submission = data;
      return { ok: true };
    };

    await render(
      <template>
        <DockedComposer
          @composerEvents={{false}}
          @draftKey="test-replace-typing"
          @onRegisterApi={{registerApi}}
          @onSubmit={{handleSubmit}}
        />
      </template>
    );

    await fillIn(".d-editor-input", "A discarded reply");
    composerApi.setReply("An existing post");
    await settled();
    await fillIn(".d-editor-input", "An existing post edited");
    await click(".docked-composer__submit-btn");

    assert.strictEqual(
      submission.typingTime,
      100,
      "only the edit counts toward the new measurement"
    );
  });

  test("counts every input when keystrokes arrive within 100 milliseconds", async function (assert) {
    let submission;
    const handleSubmit = (data) => {
      submission = data;
      return { ok: true };
    };

    await render(
      <template>
        <DockedComposer
          @composerEvents={{false}}
          @draftKey="test-rapid-typing"
          @onSubmit={{handleSubmit}}
        />
      </template>
    );

    const editor = find(".d-editor-input");
    for (const character of "hello") {
      editor.value += character;
      editor.dispatchEvent(new Event("input", { bubbles: true }));
    }
    await settled();
    await click(".docked-composer__submit-btn");

    assert.strictEqual(
      submission.raw,
      "hello",
      "the rapid input reaches the submitted comment"
    );
    assert.strictEqual(
      submission.typingTime,
      500,
      "each input counts like the regular composer"
    );
  });

  test("restores draft timing when the composer is recreated", async function (assert) {
    const clock = fakeTime("2026-11-16T00:00:00", null, true);
    const submissions = [];
    const handleSubmit = (data) => {
      submissions.push(data);
      return submissions.length > 1;
    };
    const composer = <template>
      <DockedComposer
        @composerEvents={{false}}
        @draftKey="test-restored-draft-timing"
        @onSubmit={{handleSubmit}}
      />
    </template>;

    try {
      await render(composer);
      clock.tick(5_000);
      await fillIn(".d-editor-input", "First");
      await fillIn(".d-editor-input", "First draft");
      await fillIn(".d-editor-input", "First draft ready");
      await click(".docked-composer__submit-btn");
      assert.strictEqual(
        submissions[0].typingTime,
        300,
        "the draft has recorded typing time"
      );

      await clearRender();
      clock.tick(60_000);
      await render(composer);
      assert
        .dom(".d-editor-input")
        .hasValue("First draft ready", "the draft text is restored");
      clock.tick(2_000);
      await click(".docked-composer__submit-btn");

      assert.strictEqual(
        submissions[1].typingTime,
        300,
        "the restored draft retains its typing time"
      );
      assert.true(
        submissions[1].composerTime >= 7_000,
        "open time includes both editor sessions"
      );
      assert.true(
        submissions[1].composerTime < 60_000,
        "time with the editor closed is excluded"
      );

      await clearRender();
      await render(composer);
      assert
        .dom(".d-editor-input")
        .hasValue("", "successful submission clears the saved draft");
      await fillIn(".d-editor-input", "A new comment");
      await click(".docked-composer__submit-btn");
      assert.strictEqual(
        submissions[2].typingTime,
        100,
        "a new comment has fresh timing"
      );
    } finally {
      clock.restore();
    }
  });

  test("ignores saved timing when an older client changes the draft text", async function (assert) {
    let submission;
    const handleSubmit = (data) => {
      submission = data;
      return false;
    };
    const composer = <template>
      <DockedComposer
        @composerEvents={{false}}
        @draftKey="test-changed-legacy-draft"
        @onSubmit={{handleSubmit}}
      />
    </template>;

    await render(composer);
    await fillIn(".d-editor-input", "First");
    await fillIn(".d-editor-input", "First draft");
    await fillIn(".d-editor-input", "First draft ready");
    await clearRender();

    const changedDraft = "A different draft from an older client";
    this.owner.lookup("service:key-value-store").set({
      key: "test-changed-legacy-draft",
      value: changedDraft,
    });
    await render(composer);
    await click(".docked-composer__submit-btn");

    assert.strictEqual(
      submission.raw,
      changedDraft,
      "the changed draft text is preserved"
    );
    assert.strictEqual(
      submission.typingTime,
      0,
      "another draft's timing is not reused"
    );
  });

  test("restores existing text only drafts without interpreting their contents", async function (assert) {
    const legacyDraft = '{"reply":"legacy draft text","typingTime":9000}';
    this.owner.lookup("service:key-value-store").set({
      key: "test-legacy-draft-timing",
      value: legacyDraft,
    });
    let submission;
    const handleSubmit = (data) => {
      submission = data;
      return false;
    };

    await render(
      <template>
        <DockedComposer
          @composerEvents={{false}}
          @draftKey="test-legacy-draft-timing"
          @onSubmit={{handleSubmit}}
        />
      </template>
    );
    assert
      .dom(".d-editor-input")
      .hasValue(legacyDraft, "the original draft is preserved exactly");
    await click(".docked-composer__submit-btn");
    assert.strictEqual(
      submission.raw,
      legacyDraft,
      "JSON text remains comment content"
    );
    assert.strictEqual(
      submission.typingTime,
      0,
      "missing historical timing is not fabricated"
    );
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
          @composerEvents={{false}}
          @draftKey="test-submit-enter"
          @onSubmit={{handleSubmit}}
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
          @composerEvents={{false}}
          @draftKey="test-send-shortcut-option"
          @onSubmit={{handleSubmit}}
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
          @composerEvents={{false}}
          @draftKey="test-send-shortcut-ctrl"
          @onSubmit={{handleSubmit}}
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
          @composerEvents={{false}}
          @draftKey="test-send-shortcut-override"
          @onSubmit={{handleSubmit}}
          @submitOnEnter={{true}}
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
          @composerEvents={{false}}
          @draftKey="test-no-submit-enter"
          @onSubmit={{handleSubmit}}
          @submitOnEnter={{false}}
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
          @composerEvents={{false}}
          @draftKey="test-ctrl-enter"
          @onSubmit={{handleSubmit}}
          @submitOnEnter={{false}}
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
          @composerEvents={{false}}
          @draftKey="test-meta-enter"
          @onSubmit={{handleSubmit}}
          @submitOnEnter={{false}}
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
          @composerEvents={{false}}
          @draftKey="test-auto-resize"
          @maxResizeOffset={{200}}
          @resizable={{true}}
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
          @composerEvents={{false}}
          @draftKey="test-resize-max"
          @maxResizeOffset={{200}}
          @resizable={{true}}
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
          @composerEvents={{false}}
          @draftKey="test-resize-default"
          @resizable={{true}}
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
          @composerEvents={{false}}
          @draftKey="test-resize-arrows"
          @resizable={{true}}
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
          @composerEvents={{false}}
          @draftKey="test-resize-home"
          @resizable={{true}}
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
