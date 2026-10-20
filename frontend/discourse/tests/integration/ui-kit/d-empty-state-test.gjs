import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import DEmptyState from "discourse/ui-kit/d-empty-state";

module("Integration | ui-kit | DEmptyState", function (hooks) {
  setupRenderingTest(hooks);

  test("it renders", async function (assert) {
    await render(
      <template>
        <DEmptyState @body="body" @title="user.no_bookmarks_title" />
      </template>
    );

    assert.dom("[data-test-title]").exists();
    assert.dom("[data-test-body]").exists();
  });

  test("@ctaDisabled", async function (assert) {
    await render(
      <template>
        <DEmptyState @ctaDisabled={{true}} @ctaLabel="Show all" />
      </template>
    );

    assert.dom(".empty-state__cta .btn").isDisabled();
  });
});
