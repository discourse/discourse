import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { configureEyeline } from "discourse/lib/eyeline";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

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
        <table class="numbers"><tbody><tr></tr></tbody></table>
      </LoadMore>
    `);

    assert.true(this.loadedMore);
  });
});
