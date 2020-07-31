import I18n from "I18n";
import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import discourseComputed from "discourse-common/utils/decorators";
import { PIE_CHART_TYPE } from "../controllers/poll-ui-builder";
import { getColors } from "../lib/chart-colors";

// args: options, group, displayMode, highlightedOption, setHighlightedOption
export default Component.extend({
  classNames: "poll-breakdown-chart-container",
  optionToSlice: {},
  previousHighlightedSliceIndex: null,
  previousDisplayMode: null,

  didInsertElement() {
    this._super(...arguments);

    const canvas = this.element.querySelector("canvas");
    this.set(
      "chart",
      new window.Chart(canvas.getContext("2d"), this.chartConfig)
    );
  },

  didReceiveAttrs() {
    this._super(...arguments);

    if (this.chart) {
      this._updateDisplayMode();
      this._updateHighlight();
    }
  },

  willDestroy() {
    this._super(...arguments);

    if (this.chart) {
      this.chart.destroy();
    }
  },

  @discourseComputed("options")
  data(options) {
    return options.mapBy("votes");
  },

  @discourseComputed("optionColors", "index")
  colorStyle(optionColors, index) {
    return htmlSafe(`background: ${optionColors[index]};`);
  },

  @discourseComputed("data", "displayMode")
  chartConfig(data, displayMode) {
    const transformedData = [];
    let counter = 0;

    this.set("optionToSlice", {});

    data.forEach((votes, index) => {
      if (votes > 0) {
        transformedData.push(votes);
        this.optionToSlice[index] = counter++;
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
            hoverBorderColor: "#fff"
          }
        ]
      },
      options: {
        plugins: {
          datalabels: {
            color: "#333",
            backgroundColor: "rgba(255, 255, 255, 0.5)",
            borderRadius: 2,
            font: {
              family: getComputedStyle(document.body).fontFamily,
              size: 16
            },
            padding: {
              top: 2,
              right: 6,
              bottom: 2,
              left: 6
            },
            formatter(votes) {
              if (displayMode !== "percentage") {
                return votes;
              }

              const percent = I18n.toNumber((votes / totalVotes) * 100.0, {
                precision: 1
              });

              return `${percent}%`;
            }
          }
        },
        responsive: true,
        aspectRatio: 1.1,
        animation: { duration: 0 },
        tooltips: false,
        onHover: (event, activeElements) => {
          if (!activeElements.length) {
            this.setHighlightedOption(null);
            return;
          }

          const sliceIndex = activeElements[0]._index;
          const optionIndex = Object.keys(this.optionToSlice).find(
            option => this.optionToSlice[option] === sliceIndex
          );

          // Clear the array to avoid issues in Chart.js
          activeElements.length = 0;

          this.setHighlightedOption(Number(optionIndex));
        }
      }
    };
  },

  _updateDisplayMode() {
    if (this.displayMode !== this.previousDisplayMode) {
      const config = this.chartConfig;
      this.chart.data.datasets = config.data.datasets;
      this.chart.options = config.options;

      this.chart.update();
      this.set("previousDisplayMode", this.displayMode);
    }
  },

  _updateHighlight() {
    const meta = this.chart.getDatasetMeta(0);

    if (this.previousHighlightedSliceIndex !== null) {
      const slice = meta.data[this.previousHighlightedSliceIndex];
      meta.controller.removeHoverStyle(slice);
      this.chart.draw();
    }

    if (this.highlightedOption === null) {
      this.set("previousHighlightedSliceIndex", null);
      return;
    }

    const sliceIndex = this.optionToSlice[this.highlightedOption];
    if (typeof sliceIndex === "undefined") {
      this.set("previousHighlightedSliceIndex", null);
      return;
    }

    const slice = meta.data[sliceIndex];
    this.set("previousHighlightedSliceIndex", sliceIndex);
    meta.controller.setHoverStyle(slice);
    this.chart.draw();
  }
});
