import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { includes } from "truth-helpers";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Addons | truth-helpers | Integration | includes", function (hooks) {
  setupRenderingTest(hooks);

  test("when using an array", async function (assert) {
    const self = this;

    this.foo = [1];
    this.bar = 1;
    await render(
      <template>
        {{#if (includes self.foo self.bar)}}<span class="test"></span>{{/if}}
      </template>
    );

    assert.dom(".test").exists("is true when element is found");

    this.bar = 2;
    await render(
      <template>
        {{#if (includes self.foo self.bar)}}<span class="test"></span>{{/if}}
      </template>
    );

    assert.dom(".test").doesNotExist("is false when element is not found");
  });

  test("when using a string", async function (assert) {
    const self = this;

    this.foo = "foo";
    this.bar = "f";
    await render(
      <template>
        {{#if (includes self.foo self.bar)}}<span class="test"></span>{{/if}}
      </template>
    );

    assert.dom(".test").exists("is true when element is found");

    this.bar = "b";
    await render(
      <template>
        {{#if (includes self.foo self.bar)}}<span class="test"></span>{{/if}}
      </template>
    );

    assert.dom(".test").doesNotExist("is false when element is not found");
  });
});
