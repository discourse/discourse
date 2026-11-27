import { tracked } from "@glimmer/tracking";
import { find, render, rerender } from "@ember/test-helpers";
import { module, test } from "qunit";
import loadChartJS from "discourse/lib/load-chart-js";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import PollBreakdownChart from "discourse/plugins/poll/discourse/components/poll-breakdown-chart";

module("Poll | Component | PollBreakdownChart", function (hooks) {
  setupRenderingTest(hooks);

  test("highlights the slice of the highlighted option", async function (assert) {
    const Chart = await loadChartJS();
    const options = [{ votes: 2 }, { votes: 0 }, { votes: 3 }];
    const highlightedOption = tracked(null);

    await render(
      <template>
        <PollBreakdownChart
          @highlightedOption={{highlightedOption.value}}
          @options={{options}}
        />
      </template>
    );

    const chart = Chart.getChart(find(".poll-breakdown-chart-chart"));
    const activeSlices = () => chart.getActiveElements().map((e) => e.index);

    highlightedOption.value = 2;
    await rerender();
    assert.deepEqual(activeSlices(), [1], "skips options without votes");

    highlightedOption.value = 0;
    await rerender();
    assert.deepEqual(activeSlices(), [0], "highlights the first option");
  });
});
