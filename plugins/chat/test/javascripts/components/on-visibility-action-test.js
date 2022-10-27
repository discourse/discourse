import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import hbs from "htmlbars-inline-precompile";
import { render, waitUntil } from "@ember/test-helpers";
import { module, test } from "qunit";

module("Discourse Chat | Component | on-visibility-action", function (hooks) {
  setupRenderingTest(hooks);

  test("Calling an action on visibility gained", async function (assert) {
    this.set("value", null);
    this.set("display", false);
    this.set("action", () => {
      this.set("value", "foo");
    });

    this.set("root", document.querySelector("#ember-testing"));

    await render(
      hbs`{{#if display}}{{on-visibility-action action=action root=root}}{{/if}}`
    );

    assert.equal(this.value, null);

    this.set("display", true);
    await waitUntil(() => this.value !== null);

    assert.equal(this.value, "foo");
  });
});
