import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteSkeleton from "discourse/components/site-skeleton";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Component | SiteSkeleton", function (hooks) {
  setupRenderingTest(hooks);

  test("renders an inert, decorative placeholder skeleton", async function (assert) {
    await render(<template><SiteSkeleton /></template>);

    assert
      .dom(".site-skeleton")
      .hasAttribute("aria-hidden", "true", "is hidden from assistive tech");
    assert
      .dom(".site-skeleton__topic")
      .exists({ count: 3 }, "renders the placeholder topic cards");
    assert
      .dom(".site-skeleton__bar")
      .exists("represents content as placeholder bars");
  });

  test("renders no real text content", async function (assert) {
    await render(<template><SiteSkeleton /></template>);

    // Content is placeholder boxes/icons, so no real strings should render.
    assert.dom(".site-skeleton").hasText("");
  });
});
