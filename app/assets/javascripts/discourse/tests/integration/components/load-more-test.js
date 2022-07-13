import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import { configureEyeline } from "discourse/lib/eyeline";
import { hbs } from "ember-cli-htmlbars";

module("Integration | Component | load-more", function (hooks) {
  setupRenderingTest(hooks);

  hooks.beforeEach(function () {
    configureEyeline({
      skipUpdate: false,
      rootElement: "#ember-testing",
    });
  });

  hooks.afterEach(function () {
    configureEyeline();
  });

  test("updates once after initialization", async function (assert) {
    this.set("loadMore", () => this.set("loadedMore", true));

    await render(hbs`
      <LoadMore @selector=".numbers tr" @action={{this.loadMore}}>
        <table class="numbers"><tr></tr></table>
      </LoadMore>
    `);

    assert.ok(this.loadedMore);
  });
});
