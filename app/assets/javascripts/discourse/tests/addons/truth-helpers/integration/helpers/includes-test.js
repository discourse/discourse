import { assert, module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { exists } from "discourse/tests/helpers/qunit-helpers";

module("Addons | truth-helpers | Integration | includes", function (hooks) {
  setupRenderingTest(hooks);

  test("when using an array", async function () {
    this.foo = [1];
    this.bar = 1;
    await render(
      hbs`{{#if (includes foo bar)}}<span class="test"></span>{{/if}}`
    );

    assert.ok(exists(".test"), "it returns true when element is found");

    this.bar = 2;
    await render(
      hbs`{{#if (includes foo bar)}}<span class="test"></span>{{/if}}`
    );

    assert.notOk(exists(".test"), "it returns false when element is not found");
  });

  test("when using a string", async function () {
    this.foo = "foo";
    this.bar = "f";
    await render(
      hbs`{{#if (includes foo bar)}}<span class="test"></span>{{/if}}`
    );

    assert.ok(exists(".test"), "it returns true when element is found");

    this.bar = "b";
    await render(
      hbs`{{#if (includes foo bar)}}<span class="test"></span>{{/if}}`
    );

    assert.notOk(exists(".test"), "it returns false when element is not found");
  });
});
