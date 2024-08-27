import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import AceEditor from "discourse/components/ace-editor";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | ace-editor", function (hooks) {
  setupRenderingTest(hooks);

  test("css editor", async function (assert) {
    await render(<template><AceEditor @mode="css" /></template>);
    assert.dom(".ace_editor").exists("it renders the ace editor");
  });

  test("html editor", async function (assert) {
    await render(<template>
      <AceEditor @mode="html" @content="<b>wat</b>" />
    </template>);
    assert.dom(".ace_editor").exists("it renders the ace editor");
  });

  test("sql editor", async function (assert) {
    await render(<template>
      <AceEditor @mode="sql" @content="SELECT * FROM users" />
    </template>);
    assert.dom(".ace_editor").exists("it renders the ace editor");
  });

  test("yaml editor", async function (assert) {
    await render(<template>
      <AceEditor @mode="yaml" @content="test: true" />
    </template>);
    assert.dom(".ace_editor").exists("it renders the ace editor");
  });

  test("javascript editor", async function (assert) {
    await render(<template>
      <AceEditor @mode="javascript" @content="test: true" />
    </template>);
    assert.dom(".ace_editor").exists("it renders the ace editor");
  });

  test("disabled editor", async function (assert) {
    await render(<template>
      <AceEditor
        @mode="sql"
        @content="SELECT * FROM users"
        @disabled={{true}}
      />
    </template>);

    assert.dom(".ace_editor").exists("it renders the ace editor");
    assert
      .dom(".ace-wrapper")
      .hasAttribute("data-disabled", "true", "it has a data-disabled attr");
  });
});
