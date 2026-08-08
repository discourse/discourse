import {
  find,
  findAll,
  focus,
  render,
  settled,
  triggerEvent,
  triggerKeyEvent,
} from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import AceEditor from "discourse/components/ace-editor";
import { headerOffset } from "discourse/lib/offset-calculator";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { stubPointerCapture } from "discourse/tests/helpers/ui-kit/pointer-gesture-helper";
import { i18n } from "discourse-i18n";

async function dragResizeEdge(element, { from, to, pointerId = 1 }) {
  stubPointerCapture(element);

  await triggerEvent(element, "pointerdown", {
    button: 0,
    clientY: from,
    pointerId,
  });
  await triggerEvent(element, "pointermove", {
    button: 0,
    clientY: to,
    pointerId,
  });
  await triggerEvent(element, "pointerup", {
    button: 0,
    clientY: to,
    pointerId,
  });
}

module("Integration | Component | AceEditor", function (hooks) {
  setupRenderingTest(hooks);

  test("css editor", async function (assert) {
    await render(
      <template>
        <AceEditor @mode="css" style="width: 300px; height: 200px" />
      </template>
    );
    assert.dom(".ace_editor").exists("it renders the ace editor");
  });

  test("html editor", async function (assert) {
    await render(
      <template>
        <AceEditor
          @mode="html"
          @content="<b>wat</b>"
          style="width: 300px; height: 200px"
        />
      </template>
    );
    assert.dom(".ace_editor").exists("it renders the ace editor");
  });

  test("sql editor", async function (assert) {
    await render(
      <template>
        <AceEditor
          @mode="sql"
          @content="SELECT * FROM users"
          style="width: 300px; height: 200px"
        />
      </template>
    );
    assert.dom(".ace_editor").exists("it renders the ace editor");
  });

  test("yaml editor", async function (assert) {
    await render(
      <template>
        <AceEditor
          @mode="yaml"
          @content="test: true"
          style="width: 300px; height: 200px"
        />
      </template>
    );
    assert.dom(".ace_editor").exists("it renders the ace editor");
  });

  test("javascript editor", async function (assert) {
    await render(
      <template>
        <AceEditor
          @mode="javascript"
          @content="test: true"
          style="width: 300px; height: 200px"
        />
      </template>
    );
    assert.dom(".ace_editor").exists("it renders the ace editor");
  });

  test("disabled editor", async function (assert) {
    await render(
      <template>
        <AceEditor
          @mode="sql"
          @content="SELECT * FROM users"
          @disabled={{true}}
          style="width: 300px; height: 200px"
        />
      </template>
    );

    assert.dom(".ace_editor").exists("it renders the ace editor");
    assert
      .dom(".ace-wrapper")
      .hasAttribute("data-disabled", "true", "it has a data-disabled attr");
  });

  test("ACE resize oracle renders an accessible separator", async function (assert) {
    await render(
      <template>
        <AceEditor
          @mode="sql"
          @content="SELECT * FROM users"
          style="width: 300px; height: 220px; min-height: 200px; max-height: 240px"
          @resizable={{true}}
        />
      </template>
    );

    assert.dom(".ace_editor").exists("it renders the ace editor");
    assert
      .dom(".ace-wrapper .ace_editor--resizable")
      .exists("it has the resizable class");

    assert
      .dom(".ace-wrapper .grippie")
      .exists("it renders the grippie element for dragging vertically");
    assert
      .dom(".ace-wrapper .grippie")
      .hasAttribute("role", "separator", "the resize edge is a separator")
      .hasAttribute(
        "aria-orientation",
        "horizontal",
        "the separator reports its visual orientation"
      )
      .hasAttribute(
        "aria-label",
        i18n("ace_editor.resize"),
        "the separator has an accessible name"
      )
      .hasAttribute("tabindex", "0", "the separator is keyboard focusable")
      .hasAttribute(
        "aria-valuenow",
        "220",
        "the separator reports the measured editor height"
      )
      .hasAttribute(
        "aria-valuemin",
        "200",
        "the separator reports the computed minimum height"
      )
      .hasAttribute(
        "aria-valuemax",
        "240",
        "the separator honors the editor's declared maximum height"
      );
  });

  test("grippie regression ACE window resize refreshes published maximum", async function (assert) {
    const initialWindowHeight = 600;
    const expandedWindowHeight = 900;
    const innerHeightStub = sinon
      .stub(window, "innerHeight")
      .value(initialWindowHeight);

    await render(
      <template>
        <AceEditor
          @mode="sql"
          @content="SELECT * FROM users"
          style="width: 300px; height: 220px; min-height: 200px"
          @resizable={{true}}
        />
      </template>
    );

    innerHeightStub.value(expandedWindowHeight);
    window.dispatchEvent(new Event("resize"));
    await settled();

    assert
      .dom(".ace-wrapper .grippie")
      .hasAttribute(
        "aria-valuemax",
        `${expandedWindowHeight - headerOffset()}`,
        "a window resize publishes the resizable area's new maximum height"
      );
  });

  test("ACE resize oracle adjusts and clamps pointer-dragged height", async function (assert) {
    await render(
      <template>
        <button class="focus-sentinel" type="button">Keep focus</button>
        <AceEditor
          @mode="sql"
          @content="SELECT * FROM users"
          style="width: 300px; height: 260px; min-height: 200px"
          @resizable={{true}}
        />
      </template>
    );

    const editor = find(".ace_editor--resizable");
    const grippie = find(".grippie");
    const initialHeight = editor.offsetHeight;
    const startCoordinate = 47;
    const growBy = 120;
    const expectedHeight = initialHeight + growBy;

    await focus(".focus-sentinel");
    await dragResizeEdge(grippie, {
      from: startCoordinate,
      to: startCoordinate + growBy,
    });

    assert.strictEqual(
      editor.offsetHeight,
      expectedHeight,
      "height is adjusted"
    );
    assert.dom(".focus-sentinel").isFocused("resizing does not steal focus");

    await dragResizeEdge(grippie, {
      from: 611,
      to: 11,
      pointerId: 2,
    });

    assert.strictEqual(
      editor.offsetHeight,
      200,
      "height will not go past the minimum height of 200px"
    );
  });

  test("ACE resize oracle scopes pointer dragging to its own editor", async function (assert) {
    await render(
      <template>
        <AceEditor
          @mode="sql"
          @content="SELECT 1"
          style="width: 300px; height: 240px; min-height: 200px; max-height: 500px"
          @resizable={{true}}
        />
        <AceEditor
          @mode="sql"
          @content="SELECT 2"
          style="width: 300px; height: 320px; min-height: 200px; max-height: 500px"
          @resizable={{true}}
        />
      </template>
    );

    const editors = findAll(".ace_editor--resizable");
    const grippies = findAll(".grippie");

    await dragResizeEdge(grippies[1], { from: 41, to: 101 });

    assert.strictEqual(
      editors[0].offsetHeight,
      240,
      "the first editor keeps its height"
    );
    assert.strictEqual(
      editors[1].offsetHeight,
      380,
      "the second grippie resizes the second editor"
    );
  });

  test("ACE resize oracle supports arrow, Home, and End keys", async function (assert) {
    await render(
      <template>
        <AceEditor
          @mode="sql"
          @content="SELECT * FROM users"
          style="width: 300px; height: 300px; min-height: 200px; max-height: 360px"
          @resizable={{true}}
        />
      </template>
    );

    const editor = find(".ace_editor--resizable");
    const grippie = find(".grippie");

    // Released between presses: a key held down is one resize, and the size it
    // reports is announced when it settles rather than on every repeat.
    const press = async (key) => {
      await triggerKeyEvent(grippie, "keydown", key);
      await triggerKeyEvent(grippie, "keyup", key);
    };

    await press("ArrowDown");
    assert.strictEqual(editor.offsetHeight, 316, "ArrowDown grows the editor");

    await press("ArrowUp");
    assert.strictEqual(editor.offsetHeight, 300, "ArrowUp shrinks the editor");

    await press("Home");
    assert.strictEqual(
      editor.offsetHeight,
      200,
      "Home uses the minimum height"
    );

    await press("End");
    assert.strictEqual(editor.offsetHeight, 360, "End uses the maximum height");
    assert
      .dom(grippie)
      .hasAttribute(
        "aria-valuenow",
        "360",
        "keyboard resizing refreshes the reported height"
      );
  });
});
