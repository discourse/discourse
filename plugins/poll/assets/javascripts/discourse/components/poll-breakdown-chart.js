import { classNames } from "@ember-decorators/component";
import { mapBy } from "@ember/object/computed";
import Component from "@ember/component";
import I18n from "I18n";
import { PIE_CHART_TYPE } from "../components/modal/poll-ui-builder";
import discourseComputed from "discourse-common/utils/decorators";
import { getColors } from "discourse/plugins/poll/lib/chart-colors";
import { htmlSafe } from "@ember/template";
import { next } from "@ember/runloop";

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

  willDestroy() {
    super.willDestroy(...arguments);

    if (this._chart) {
      this._chart.destroy();
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

          const sliceIndex = activeElements[0]._index;
          const optionIndex = Object.keys(this._optionToSlice).find(
            (option) => this._optionToSlice[option] === sliceIndex
          );

          // Clear the array to avoid issues in Chart.js
          activeElements.length = 0;

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
    const meta = this._chart.getDatasetMeta(0);

    if (this._previousHighlightedSliceIndex !== null) {
      const slice = meta.data[this._previousHighlightedSliceIndex];
      meta.controller.removeHoverStyle(slice);
      this._chart.draw();
    }

    if (this.highlightedOption === null) {
      this._previousHighlightedSliceIndex = null;
      return;
    }

    const sliceIndex = this._optionToSlice[this.highlightedOption];
    if (typeof sliceIndex === "undefined") {
      this._previousHighlightedSliceIndex = null;
      return;
    }

    const slice = meta.data[sliceIndex];
    this._previousHighlightedSliceIndex = sliceIndex;
    meta.controller.setHoverStyle(slice);
    this._chart.draw();
  }
}
