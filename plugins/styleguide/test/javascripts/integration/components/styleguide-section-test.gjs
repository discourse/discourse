import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import sinon from "sinon";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import StyleguideSection from "discourse/plugins/styleguide/discourse/components/styleguide-section";

module("Integration | Component | StyleguideSection", function (hooks) {
  setupRenderingTest(hooks);

  test("scrolls to the top whenever another section is shown", async function (assert) {
    const scrollTo = sinon.stub(window, "scrollTo");
    const section = tracked({ id: "colors", category: "atoms" });

    await render(
      <template><StyleguideSection @section={{section.value}} /></template>
    );

    assert.strictEqual(scrollTo.callCount, 1, "scrolls when first shown");

    section.value = { id: "icons", category: "atoms" };
    await settled();

    assert.strictEqual(scrollTo.callCount, 2, "scrolls on a section change");
    assert.dom(".styleguide-section").hasClass("icons-examples");
  });
});
