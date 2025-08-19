import { render, triggerEvent } from "@ember/test-helpers";
import { module, test } from "qunit";
import AceEditor from "discourse/components/ace-editor";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

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

  test("resizable editor", async function (assert) {
    await render(
      <template>
        <AceEditor
          @mode="sql"
          @content="SELECT * FROM users"
          style="width: 300px; height: 200px"
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
  });

  test("resizable editor height adjustment", async function (assert) {
    await render(
      <template>
        <AceEditor
          @mode="sql"
          @content="SELECT * FROM users"
          style="width: 300px; min-height: 200px"
          @resizable={{true}}
        />
      </template>
    );

    const initialHeight = document.querySelector(
      ".ace_editor--resizable"
    ).offsetHeight;
    const expectedHeight = initialHeight + 300;
    await triggerEvent(".grippie", "mousedown", { clientY: initialHeight });
    await triggerEvent(".grippie", "mousemove", { clientY: expectedHeight });
    await triggerEvent(".grippie", "mouseup", { clientY: expectedHeight });

    const actualHeight = document.querySelector(
      ".ace_editor--resizable"
    ).offsetHeight;
    assert.strictEqual(expectedHeight, actualHeight, "height is adjusted");

    await triggerEvent(".grippie", "mousedown", { clientY: expectedHeight });
    await triggerEvent(".grippie", "mousemove", { clientY: 150 });
    await triggerEvent(".grippie", "mouseup", { clientY: 150 });

    assert.strictEqual(
      document.querySelector(".ace_editor--resizable").offsetHeight,
      200,
      "height will not go past the minimum height of 200px"
    );
  });
});
