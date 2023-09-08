import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import { render } from "@ember/test-helpers";
import DSection from "discourse/components/d-section";

module("Integration | Component | d-section", function (hooks) {
  setupRenderingTest(hooks);

  test("can set classes on the body element", async function (assert) {
    await render(<template>
      <DSection @pageClass="test" @bodyClass="foo bar" class="special">
        testing!
      </DSection>
    </template>);

    assert.dom(".special").hasText("testing!");
    assert.strictEqual(document.body.className, "test-page foo bar");
  });
});
