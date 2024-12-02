import { tracked } from "@glimmer/tracking";
import { render, settled } from "@ember/test-helpers";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";
import Chart from "admin/components/chart";

module("Integration | Component | Chart", function (hooks) {
  setupRenderingTest(hooks);

  function generateData() {
    let data = [];
    for (let i = 0; i < 10; i++) {
      data.push({ x: i, y: Math.random() * 10 });
    }
    return data;
  }

  // We do this because comparing hashes at a pixel level is not reliable,
  // even when calling a hash on a canvas that was not changing at all
  // I was getting different results. PNG is more solid ground and deterministic.
  // No need to hash anything, the data URLs are unique, and we are rendering
  // quite small canvases so no need to worry about perf as much.
  function renderAsPNGURL(canvas) {
    return canvas.toDataURL("image/png");
  }

  function generateChartConfig(model, options = {}) {
    return {
      type: "bar",
      data: {
        labels: model.data.map((r) => r.x),
        datasets: [
          {
            data: model.data.map((r) => r.y),
            label: model.title,
            backgroundColor: options.backgroundColor || "rgba(200,220,240,1)",
          },
        ],
      },
      // We don't want anything messing with the canvas rendering by
      // moving things around as we are trying to capture it.
      options: {
        animation: false,
        responsive: false,
        maintainAspectRatio: false,
      },
    };
  }

  test("renders a chart", async function (assert) {
    this.model = {
      title: "Test Chart",
      data: generateData(),
    };

    const chartConfig = generateChartConfig(this.model);
    await render(<template><canvas class="empty-canvas"></canvas></template>);
    const emptyCanvasDataURL = await renderAsPNGURL(
      document.querySelector("canvas.empty-canvas")
    );
    await render(<template><Chart @chartConfig={{chartConfig}} /></template>);
    const dataURL = await renderAsPNGURL(
      document.querySelector("canvas.chart-canvas")
    );
    assert.notStrictEqual(
      emptyCanvasDataURL,
      dataURL,
      "The canvas was rendered successfully"
    );
  });

  test("rerenders the chart if the config changes", async function (assert) {
    this.model = {
      title: "Test Chart",
      data: generateData(),
    };

    const testState = new (class {
      @tracked chartConfig;
    })();

    testState.chartConfig = generateChartConfig(this.model);

    await render(<template>
      <Chart @chartConfig={{testState.chartConfig}} />
    </template>);
    const firstCanvasDataURL = await renderAsPNGURL(
      document.querySelector("canvas.chart-canvas")
    );

    testState.chartConfig = generateChartConfig(this.model, {
      backgroundColor: "red",
    });

    await settled();
    const secondCanvasDataURL = await renderAsPNGURL(
      document.querySelector("canvas.chart-canvas")
    );

    assert.notStrictEqual(
      firstCanvasDataURL,
      secondCanvasDataURL,
      "The canvases are not identical, so the chart rerendered successfully"
    );
  });
});
