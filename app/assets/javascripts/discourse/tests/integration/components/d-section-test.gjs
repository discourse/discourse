import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DSection from "discourse/components/d-section";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { withSilencedDeprecationsAsync } from "discourse-common/lib/deprecated";

module("Integration | Component | d-section", function (hooks) {
  setupRenderingTest(hooks);

  test("can set classes on the body element", async function (assert) {
    await withSilencedDeprecationsAsync("discourse.d-section", async () => {
      await render(<template>
        <DSection @pageClass="test" @bodyClass="foo bar" class="special">
          testing!
        </DSection>
      </template>);
    });

    assert.dom(".special").hasText("testing!");
    assert.strictEqual(document.body.className, "test-page foo bar");
  });
});
