import { module, test } from "qunit";
import { setupRenderingTest } from "ember-qunit";
import { render } from "@ember/test-helpers";
import hbs from "htmlbars-inline-precompile";

const LEGACY_ENV = !setupRenderingTest;

module("Integration | Component | empty-state", function (hooks) {
  if (LEGACY_ENV) {
    return;
  }

  setupRenderingTest(hooks);

  test("it renders", async function (assert) {
    await render(hbs`
      <EmptyState @title="title" @body="body" />
    `);

    assert.dom("[data-test-title]").hasText("title");
    assert.dom("[data-test-body]").hasText("body");
  });
});
