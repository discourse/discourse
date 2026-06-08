import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import HorizonSiteSkeleton from "discourse/components/horizon-site-skeleton";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | HorizonSiteSkeleton", function (hooks) {
  setupRenderingTest(hooks);

  test("renders an inert, decorative placeholder skeleton", async function (assert) {
    await render(<template><HorizonSiteSkeleton /></template>);

    assert
      .dom(".horizon-site-skeleton")
      .hasAttribute("aria-hidden", "true", "is hidden from assistive tech");
    assert
      .dom(".horizon-site-skeleton__topic")
      .exists({ count: 3 }, "renders the placeholder topic cards");
    assert
      .dom(".horizon-site-skeleton__bar")
      .exists("represents content as placeholder bars");
  });

  test("renders no real text content", async function (assert) {
    await render(<template><HorizonSiteSkeleton /></template>);

    // Content is placeholder boxes/icons, so no real strings should render.
    assert.dom(".horizon-site-skeleton").hasText("");
  });
});
