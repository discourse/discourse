import I18n from "I18n";
import Controller from "@ember/controller";
import { action } from "@ember/object";
import { classify } from "@ember/string";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import discourseComputed from "discourse-common/utils/decorators";
import { PIE_CHART_TYPE } from "../controllers/poll-ui-builder";
import { getColors } from "../lib/chart-colors";

// TODO: Move inside the component?
function pieChartConfig(data, displayMode) {
  const transformedData = data.filter(votes => votes > 0);
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
          backgroundColor: colors
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
      tooltips: false
    }
  };
}

export default Controller.extend(ModalFunctionality, {
  model: null,
  groupedBy: null,
  displayMode: "percentage",

  @discourseComputed("model.groupableUserFields")
  groupableUserFields(fields) {
    return fields.map(field => ({
      id: field,
      label: transformUserFieldToLabel(field)
    }));
  },

  @discourseComputed("model.poll.options")
  totalVotes(options) {
    return options.reduce((sum, option) => sum + option.votes, 0);
  },

  onShow() {
    console.log(this.model);
    this.set("groupedBy", this.model.groupableUserFields[0]);
    this.refreshCharts();
  },

  refreshCharts() {
    const { model } = this;

    const element = document.querySelector(".poll-breakdown-charts");
    if (element) {
      Array.from(
        element.getElementsByClassName("poll-grouped-pie-container")
      ).forEach(container => element.removeChild(container));
    }

    return ajax("/polls/grouped_poll_results.json", {
      data: {
        post_id: model.post.id,
        poll_name: model.poll.name,
        user_field_name: this.groupedBy
      }
    })
      .catch(error => {
        if (error) {
          popupAjaxError(error);
        } else {
          bootbox.alert(I18n.t("poll.error_while_fetching_voters"));
        }
      })
      .then(result => {
        const parent = document.querySelector(".poll-breakdown-charts");

        if (!parent) {
          return;
        }

        this.set("charts", []);
        this.set("dataSets", []);

        for (
          let chartIdx = 0;
          chartIdx < result.grouped_results.length;
          chartIdx++
        ) {
          const data = result.grouped_results[chartIdx].options.mapBy("votes");
          this.dataSets[chartIdx] = data;

          const chartConfig = pieChartConfig(data, this.displayMode);
          const canvasId = `pie-${model.id}-${chartIdx}`;
          let el = document.querySelector(`#${canvasId}`);

          if (el) {
            // eslint-disable-next-line
            Chart.helpers.each(Chart.instances, instance => {
              if (instance.chart.canvas.id === canvasId && el.$chartjs) {
                instance.destroy();
                // eslint-disable-next-line
                new Chart(el.getContext("2d"), chartConfig);
              }
            });
          } else {
            const container = document.createElement("div");
            container.classList.add("poll-grouped-pie-container");

            const label = document.createElement("label");
            label.classList.add("poll-pie-label");
            label.textContent = result.grouped_results[chartIdx].group;

            const canvas = document.createElement("canvas");
            canvas.classList.add(`poll-grouped-pie-${model.id}`);
            canvas.id = canvasId;

            container.appendChild(label);
            container.appendChild(canvas);
            parent.appendChild(container);

            // eslint-disable-next-line
            const chart = new Chart(canvas.getContext("2d"), chartConfig);
            this.charts.push(chart);
          }
        }
      });
  },

  @action
  setGrouping(value) {
    this.set("groupedBy", value); // TODO: rename to groupBy
    this.refreshCharts();
  },

  @action
  onSelectPanel(panel) {
    this.set("displayMode", panel.id);

    this.charts.forEach((chart, index) => {
      const config = pieChartConfig(this.dataSets[index], this.displayMode);
      chart.data.datasets = config.data.datasets;
      chart.options = config.options;
      chart.update();
    });
  }
});

function transformUserFieldToLabel(fieldName) {
  let transformed = fieldName.split("_").filter(Boolean);
  if (transformed.length > 1) {
    transformed[0] = classify(transformed[0]);
  }
  return transformed.join(" ");
}
