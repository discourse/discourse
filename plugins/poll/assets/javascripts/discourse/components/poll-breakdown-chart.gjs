import Component from "@ember/component";
import { mapBy } from "@ember/object/computed";
import { next } from "@ember/runloop";
import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import I18n from "discourse-i18n";
import { getColors } from "discourse/plugins/poll/lib/chart-colors";
import { PIE_CHART_TYPE } from "../components/modal/poll-ui-builder";

@classNames("poll-breakdown-chart-container")
export default class PollBreakdownChart extends Component {
  // Arguments:
  group = null;
  options = null;
  displayMode = null;
  highlightedOption = null;
  setHighlightedOption = null;

  @mapBy("options", "votes") data;

  _optionToSlice = null;
  _previousHighlightedSliceIndex = null;
  _previousDisplayMode = null;

  init() {
    super.init(...arguments);
    this._optionToSlice = {};
  }

  willDestroy() {
    super.willDestroy(...arguments);

    if (this._chart) {
      this._chart.destroy();
    }
  }

  didInsertElement() {
    super.didInsertElement(...arguments);

    const canvas = this.element.querySelector("canvas");
    this._chart = new window.Chart(canvas.getContext("2d"), this.chartConfig);
  }

  didReceiveAttrs() {
    super.didReceiveAttrs(...arguments);

    if (this._chart) {
      this._updateDisplayMode();
      this._updateHighlight();
    }
  }

  @discourseComputed("optionColors", "index")
  colorStyle(optionColors, index) {
    return htmlSafe(`background: ${optionColors[index]};`);
  }

  @discourseComputed("data", "displayMode")
  chartConfig(data, displayMode) {
    const transformedData = [];
    let counter = 0;

    this._optionToSlice = {};

    data.forEach((votes, index) => {
      if (votes > 0) {
        transformedData.push(votes);
        this._optionToSlice[index] = counter++;
      }
    });

    const totalVotes = transformedData.reduce((sum, votes) => sum + votes, 0);
    const colors = getColors(data.length).filter(
      (color, index) => data[index] > 0
    );

    return {
      type: PIE_CHART_TYPE,
      plugins: [window.ChartDataLabels],
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
              this.setHighlightedOption(null);
            });
            return;
          }

          const sliceIndex = activeElements[0].index;
          const optionIndex = Object.keys(this._optionToSlice).find(
            (option) => this._optionToSlice[option] === sliceIndex
          );

          next(() => {
            this.setHighlightedOption(Number(optionIndex));
          });
        },
      },
    };
  }

  _updateDisplayMode() {
    if (this.displayMode !== this._previousDisplayMode) {
      const config = this.chartConfig;
      this._chart.data.datasets = config.data.datasets;
      this._chart.options = config.options;

      this._chart.update();
      this._previousDisplayMode = this.displayMode;
    }
  }

  _updateHighlight() {
    const activeElements = [];

    if (this.highlightedOption) {
      const index = this._optionToSlice[this.highlightedOption];

      if (index !== undefined) {
        activeElements.push({ datasetIndex: 0, index });
      }
    }

    this._chart.setActiveElements(activeElements);
    this._chart.update();
  }

  <template>
    <label class="poll-breakdown-chart-label">{{@group}}</label>
    <canvas class="poll-breakdown-chart-chart"></canvas>
  </template>
}
