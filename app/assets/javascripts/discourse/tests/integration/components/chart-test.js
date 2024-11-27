import { render } from "@ember/test-helpers";
import { hbs } from "ember-cli-htmlbars";
import { module, test } from "qunit";
import { setupRenderingTest } from "discourse/tests/helpers/component-test";

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
  // I was getting different results. PNG is more solid ground, and you can
  // compare it visually easier too.
  async function hashCanvasRenderedPNG(canvas) {
    const dataURL = canvas.toDataURL("image/png");
    const encoder = new TextEncoder();
    const buffer = encoder.encode(dataURL);

    const hashBuffer = await crypto.subtle.digest("SHA-256", buffer);

    return Array.from(new Uint8Array(hashBuffer))
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");
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
      // We don't want anything messing with the canvas rendering or hashing.
      options: {
        animation: false,
        responsive: false,
        maintainAspectRatio: false,
      },
    };
  }

  test("it renders a chart", async function (assert) {
    this.model = {
      title: "Test Chart",
      data: generateData(),
    };

    this.chartConfig = generateChartConfig(this.model);

    await render(hbs`<Chart @chartConfig={{this.chartConfig}} />`);
    assert.dom("canvas.chart-canvas").exists();
    const hash = await hashCanvasRenderedPNG(
      document.querySelector("canvas.chart-canvas")
    );
    assert.ok(hash !== "", "The canvas was rendered successfully");
  });

  test("it rerenders the chart if the config changes", async function (assert) {
    this.model = {
      title: "Test Chart",
      data: generateData(),
    };

    this.set("chartConfig", generateChartConfig(this.model));

    await render(hbs`<Chart @chartConfig={{this.chartConfig}} />`);
    const firstConfigHash = await hashCanvasRenderedPNG(
      document.querySelector("canvas.chart-canvas")
    );

    this.set(
      "chartConfig",
      generateChartConfig(this.model, { backgroundColor: "red" })
    );
    const secondConfigHash = await hashCanvasRenderedPNG(
      document.querySelector("canvas.chart-canvas")
    );

    assert.ok(
      firstConfigHash !== secondConfigHash,
      "The canvases are not identical, so the chart rerendered successfully"
    );
  });
});
