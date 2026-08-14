import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import SiteTrafficExplorerPageviewCount from "discourse/admin/components/site-traffic-explorer-pageview-count";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | SiteTrafficExplorerPageviewCount",
  function (hooks) {
    setupRenderingTest(hooks);

    test("renders a compact count without an interactive role", async function (assert) {
      await render(
        <template>
          <SiteTrafficExplorerPageviewCount @value={{13401}} as |count|>
            {{count}}
          </SiteTrafficExplorerPageviewCount>
        </template>
      );

      assert.dom(".fk-d-tooltip__trigger").hasText("13K", "formats the count");
      assert
        .dom(".fk-d-tooltip__trigger")
        .doesNotHaveAttribute(
          "role",
          "keeps the surrounding control interactive"
        );
      assert
        .dom(".fk-d-tooltip__trigger")
        .hasAttribute("title", "13,401", "exposes the unabridged count");
    });
  }
);
