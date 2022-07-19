import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { exists } from "discourse/tests/helpers/qunit-helpers";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Helper | emoji", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders", async function (assert) {
    await render(hbs`{{emoji "tada"}}`);
    assert.ok(exists(`.emoji[title="tada"]`));
  });

  test("it renders custom title", async function (assert) {
    const title = "custom title";
    this.set("title", title);

    await render(hbs`{{emoji "tada" title=this.title}}`);

    assert.ok(exists(`.emoji[title="${title}"]`));
  });
});
