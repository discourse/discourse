import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import BlockOutlet, {
  _resetOutletLayoutsForTesting,
} from "discourse/blocks/block-outlet";
import CtaBanner from "discourse/blocks/builtin/cta-banner";
import { withPluginApi } from "discourse/lib/plugin-api";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module("Integration | Blocks | cta-banner", function (hooks) {
  setupRenderingTest(hooks);

  hooks.afterEach(function () {
    _resetOutletLayoutsForTesting();
  });

  test("renders a leading icon and an external new-tab button", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: CtaBanner,
          args: {
            title: "Get started",
            icon: "rocket",
            linkLabel: "Sign up",
            linkHref: "https://example.com",
            external: true,
          },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert.dom(".d-block-cta-banner").exists("the banner renders");
    assert
      .dom(".d-block-cta-banner__icon[data-block-arg='icon'] .d-icon-rocket")
      .exists("the leading icon renders from the icon arg");
    assert
      .dom(".d-block-cta-banner__actions a[data-block-arg='linkHref']")
      .hasAttribute("href", "https://example.com")
      .hasAttribute("target", "_blank", "the external link opens in a new tab")
      .hasAttribute("rel", "noopener");
  });

  test("omits the icon and new-tab target by default", async function (assert) {
    withPluginApi((api) =>
      api.renderBlocks("hero-blocks", [
        {
          block: CtaBanner,
          args: {
            title: "Get started",
            linkLabel: "Sign up",
            linkHref: "/signup",
          },
        },
      ])
    );

    await render(<template><BlockOutlet @name="hero-blocks" /></template>);

    assert
      .dom(".d-block-cta-banner__icon")
      .doesNotExist("no icon marker without an icon arg");
    assert
      .dom(".d-block-cta-banner__actions a[data-block-arg='linkHref']")
      .doesNotHaveAttribute(
        "target",
        "the link stays same-tab without the external arg"
      );
  });
});
