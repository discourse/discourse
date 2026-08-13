import { render } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import SupportSection from "discourse/plugins/discourse-solved/admin/components/dashboard/support";

module(
  "Integration | Component | Dashboard | Support headline behavior",
  function (hooks) {
    setupRenderingTest(hooks);

    test("summarizes the measurable metric when reply time is unavailable", async function (assert) {
      const data = {
        category_options: [],
        kpis: {
          resolution_rate: { value: 72, previous_value: 60, report_query: {} },
          staff_involvement: { value: null, previous_value: null },
          avg_first_reply: { value: null, previous_value: null },
        },
        topic_outcomes: { resolved: 1, in_progress: 0, unanswered: 0 },
        whos_answering: { rows: [], total: 0 },
        response_time_distribution: {
          buckets: [],
          trend: { direction: "flat", seconds: 0 },
        },
      };

      await render(
        <template>
          <SupportSection @data={{data}} @period="last_30_days" />
        </template>
      );

      assert
        .dom(".db-section__subintro")
        .hasText(
          "The resolution rate has improved in the last 30 days More questions are getting answered."
        );
    });

    test("treats no prior support activity as a zero baseline", async function (assert) {
      const data = {
        category_options: [],
        kpis: {
          resolution_rate: {
            value: 72,
            previous_value: null,
            report_query: {},
          },
          staff_involvement: { value: 50, previous_value: null },
          avg_first_reply: { value: 0, previous_value: null },
        },
        topic_outcomes: { resolved: 1, in_progress: 0, unanswered: 0 },
        whos_answering: { rows: [], total: 0 },
        response_time_distribution: {
          buckets: [],
          trend: { direction: "flat", seconds: 0 },
        },
      };

      await render(
        <template>
          <SupportSection @data={{data}} @period="last_30_days" />
        </template>
      );

      assert
        .dom(".db-section__subintro")
        .hasText(
          "The resolution rate has improved in the last 30 days More questions are getting answered, but the time to first reply has increased. Check out the unanswered topics to see which you can address."
        );
    });

    test("preserves the no-data headline when no metric is measurable", async function (assert) {
      const data = {
        category_options: [],
        kpis: {
          resolution_rate: { value: null, previous_value: null },
          staff_involvement: { value: null, previous_value: null },
          avg_first_reply: { value: null, previous_value: null },
        },
        topic_outcomes: { resolved: 0, in_progress: 0, unanswered: 0 },
        whos_answering: { rows: [], total: 0 },
        response_time_distribution: {
          buckets: [],
          trend: { direction: "flat", seconds: 0 },
        },
      };

      await render(
        <template>
          <SupportSection @data={{data}} @period="last_30_days" />
        </template>
      );

      assert
        .dom(".db-section__subintro")
        .hasText(
          "Not enough support activity yet There's no support activity in this period yet. Once topics come in, you'll see how your community is handling them."
        );
    });
  }
);
