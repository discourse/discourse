import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import DashboardSearch from "discourse/admin/components/dashboard/search";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

module(
  "Integration | Component | Dashboard | Search headline behavior",
  function (hooks) {
    setupRenderingTest(hooks);

    test("treats no prior searches as a zero baseline", async function (assert) {
      const search = {
        logging_enabled: true,
        kpis: {
          total_searches: { value: 10, previous_value: 0 },
          no_result_rate: {
            value: 20,
            previous_value: null,
            exceeds_threshold: true,
          },
        },
        trending: [],
        content_gaps: [],
        trending_period: "monthly",
      };

      await render(
        <template>
          <DashboardSearch @search={{search}} @period="last_30_days" />
        </template>
      );

      assert
        .dom(".db-section__subintro")
        .hasText(
          "The total number of searches has increased in the last 30 days Members are conducting more searches in your community, but the no-result rate has increased. Review the content gaps to see what's missing."
        );
    });
  }
);
