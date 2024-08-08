import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { modifier } from "ember-modifier";
import loadScript from "discourse/lib/load-script";
import discourseDebounce from "discourse-common/lib/debounce";
import { bind } from "discourse-common/utils/decorators";

// args:
// chartConfig - object
export default class Chart extends Component {
  @tracked rerenderTrigger;

  renderChart = modifier((element) => {
    // consume the prop to re-run the modifier when the prop changes
    this.rerenderTrigger;

    loadScript("/javascripts/Chart.min.js").then(() => {
      this.chart = new window.Chart(
        element.getContext("2d"),
        this.args.chartConfig
      );
    });

    return () => this.chart?.destroy();
  });

  constructor() {
    super(...arguments);
    window.addEventListener("resize", this.resizeHandler);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    window.removeEventListener("resize", this.resizeHandler);
  }

  @bind
  resizeHandler() {
    discourseDebounce(this, this.rerenderChart, 500);
  }

  @bind
  rerenderChart() {
    this.rerenderTrigger = true;
  }

  <template>
    <div ...attributes>
      <div class="chart-canvas-container">
        <canvas {{this.renderChart}} class="chart-canvas"></canvas>
      </div>
    </div>
  </template>
}
