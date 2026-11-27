import Component from "@glimmer/component";
import { next } from "@ember/runloop";
import { modifier } from "ember-modifier";
import loadChartJS, {
  loadChartJSDatalabels,
} from "discourse/lib/load-chart-js";
import I18n from "discourse-i18n";
import { getColors } from "discourse/plugins/poll/lib/chart-colors";
import { PIE_CHART_TYPE } from "../components/modal/poll-ui-builder.gjs";

export default class PollBreakdownChart extends Component {
  setupChart = modifier((canvas) => {
    this.#createChart(canvas);
  });
  updateChart = modifier(() => {
    // Read before the check, so this re-runs on changes made while the chart loads
    const { displayMode, highlightedOption } = this.args;

    if (this._chart) {
      this.#updateDisplayMode(displayMode);
      this.#updateHighlight(highlightedOption);
    }
  });

  _optionToSlice = {};

  _previousDisplayMode = null;

  /** @type {import("chart.js").Chart | null} */
  _chart = null;

  willDestroy() {
    super.willDestroy(...arguments);

    if (this._chart) {
      this._chart.destroy();
    }
  }

  get data() {
    return this.args.options?.map?.((item) => item.votes) ?? [];
  }

  get chartConfig() {
    const data = this.data;
    const displayMode = this.args.displayMode;
    const transformedData = [];
    let counter = 0;

    this._optionToSlice = {}; // eslint-disable-line ember/no-side-effects

    data.forEach((votes, index) => {
      if (votes > 0) {
        transformedData.push(votes);
        this._optionToSlice[index] = counter++; // eslint-disable-line ember/no-side-effects
      }
    });

    const totalVotes = transformedData.reduce((sum, votes) => sum + votes, 0);
    const colors = getColors(data.length).filter(
      (color, index) => data[index] > 0
    );

    return {
      type: PIE_CHART_TYPE,
      data: {
        datasets: [
          {
            data: transformedData,
            backgroundColor: colors,
            // TODO: It's a workaround for Chart.js' terrible hover styling.
            // It will break on non-white backgrounds.
            // Should be updated after #10341 lands
            hoverBorderColor: "#fff",
          },
        ],
      },
      options: {
        plugins: {
          tooltip: false,
          datalabels: {
            color: "#333",
            backgroundColor: "rgba(255, 255, 255, 0.5)",
            borderRadius: 2,
            font: {
              family: getComputedStyle(document.body).fontFamily,
              size: 16,
            },
            padding: {
              top: 2,
              right: 6,
              bottom: 2,
              left: 6,
            },
            formatter(votes) {
              if (displayMode !== "percentage") {
                return votes;
              }

              const percent = I18n.toNumber((votes / totalVotes) * 100.0, {
                precision: 1,
              });

              return `${percent}%`;
            },
          },
        },
        responsive: true,
        aspectRatio: 1.1,
        animation: { duration: 0 },

        // wrapping setHighlightedOption in next block as hover can create many events
        // prevents two sets to happen in the same computation
        onHover: (event, activeElements) => {
          if (!activeElements.length) {
            next(() => {
              this.args.setHighlightedOption(null);
            });
            return;
          }

          const sliceIndex = activeElements[0].index;
          const optionIndex = Object.keys(this._optionToSlice).find(
            (option) => this._optionToSlice[option] === sliceIndex
          );

          next(() => {
            this.args.setHighlightedOption(Number(optionIndex));
          });
        },
      },
    };
  }

  async #createChart(canvas) {
    const [Chart, ChartDataLabelsPlugin] = await Promise.all([
      loadChartJS(),
      loadChartJSDatalabels(),
    ]);
    this._chart = new Chart(canvas.getContext("2d"), {
      ...this.chartConfig,
      plugins: [ChartDataLabelsPlugin],
    });
  }

  #updateDisplayMode(displayMode) {
    if (displayMode !== this._previousDisplayMode) {
      const config = this.chartConfig;
      this._chart.data.datasets = config.data.datasets;
      this._chart.options = config.options;

      this._chart.update();
      this._previousDisplayMode = displayMode;
    }
  }

  #updateHighlight(highlightedOption) {
    const activeElements = [];

    if (highlightedOption != null) {
      const index = this._optionToSlice[highlightedOption];

      if (index !== undefined) {
        activeElements.push({ datasetIndex: 0, index });
      }
    }

    this._chart.setActiveElements(activeElements);
    this._chart.update();
  }

  <template>
    <div class="poll-breakdown-chart-container" ...attributes>
      <label class="poll-breakdown-chart-label">{{@group}}</label>
      <canvas
        class="poll-breakdown-chart-chart"
        {{this.setupChart}}
        {{this.updateChart}}
      ></canvas>
    </div>
  </template>
}
