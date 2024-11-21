import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Addons | truth-helpers | Integration | includes", function (hooks) {
  setupRenderingTest(hooks);

  test("when using an array", async function (assert) {
    this.foo = [1];
    this.bar = 1;
    await render(
      hbs`{{#if (includes this.foo this.bar)}}<span class="test"></span>{{/if}}`
    );

    assert.dom(".test").exists("is true when element is found");

    this.bar = 2;
    await render(
      hbs`{{#if (includes this.foo this.bar)}}<span class="test"></span>{{/if}}`
    );

    assert.dom(".test").doesNotExist("is false when element is not found");
  });

  test("when using a string", async function (assert) {
    this.foo = "foo";
    this.bar = "f";
    await render(
      hbs`{{#if (includes this.foo this.bar)}}<span class="test"></span>{{/if}}`
    );

    assert.dom(".test").exists("is true when element is found");

    this.bar = "b";
    await render(
      hbs`{{#if (includes this.foo this.bar)}}<span class="test"></span>{{/if}}`
    );

    assert.dom(".test").doesNotExist("is false when element is not found");
  });
});
