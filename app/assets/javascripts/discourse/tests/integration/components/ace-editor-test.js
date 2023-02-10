import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { count, exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | ace-editor", function (hooks) {
  setupRenderingTest(hooks);

  test("css editor", async function (assert) {
    await render(hbs`<AceEditor @mode="css" />`);
    assert.ok(exists(".ace_editor"), "it renders the ace editor");
  });

  test("html editor", async function (assert) {
    await render(hbs`<AceEditor @mode="html" @content="<b>wat</b>" />`);
    assert.ok(exists(".ace_editor"), "it renders the ace editor");
  });

  test("sql editor", async function (assert) {
    await render(hbs`<AceEditor @mode="sql" @content="SELECT * FROM users" />`);
    assert.ok(exists(".ace_editor"), "it renders the ace editor");
  });

  test("yaml editor", async function (assert) {
    await render(hbs`<AceEditor @mode="yaml" @content="test: true" />`);
    assert.ok(exists(".ace_editor"), "it renders the ace editor");
  });

  test("disabled editor", async function (assert) {
    await render(hbs`
      <AceEditor @mode="sql" @content="SELECT * FROM users" @disabled=true />
    `);

    assert.ok(exists(".ace_editor"), "it renders the ace editor");
    assert.strictEqual(
      count(".ace-wrapper[data-disabled]"),
      1,
      "it has a data-disabled attr"
    );
  });
});
