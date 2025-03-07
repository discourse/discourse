import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import LoadMore from "discourse/components/load-more";
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
    const self = this;

    this.set("loadMore", () => this.set("loadedMore", true));

    await render(
      <template>
        <LoadMore @selector=".numbers tr" @action={{self.loadMore}}>
          <table class="numbers"><tbody><tr></tr></tbody></table>
        </LoadMore>
      </template>
    );

    assert.true(this.loadedMore);
  });
});
