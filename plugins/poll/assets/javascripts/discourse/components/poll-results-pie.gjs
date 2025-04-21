import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { htmlSafe } from "@ember/template";
import { modifier } from "ember-modifier";
import loadScript from "discourse/lib/load-script";
import { getColors } from "discourse/plugins/poll/lib/chart-colors";
import { PIE_CHART_TYPE } from "../components/modal/poll-ui-builder";

export default class PollResultsPieComponent extends Component {
  htmlLegendPlugin = {
    id: "htmlLegend",

    afterUpdate(chart, args, options) {
      const ul = document.getElementById(options.containerID);
      if (!ul) {
        return;
      }

      ul.innerHTML = "";

      const items = chart.options.plugins.legend.labels.generateLabels(chart);
      items.forEach((item) => {
        const li = document.createElement("li");
        li.classList.add("legend");
        li.onclick = () => {
          chart.toggleDataVisibility(item.index);
          chart.update();
        };

        const boxSpan = document.createElement("span");
        boxSpan.classList.add("swatch");
        boxSpan.style.background = item.fillStyle;

        const textContainer = document.createElement("span");
        textContainer.style.color = item.fontColor;
        textContainer.innerHTML = item.text;

        if (!chart.getDataVisibility(item.index)) {
          li.style.opacity = 0.2;
        } else {
          li.style.opacity = 1.0;
        }

        li.appendChild(boxSpan);
        li.appendChild(textContainer);

        ul.appendChild(li);
      });
    },
  };

  stripHtml = (html) => {
    let doc = new DOMParser().parseFromString(html, "text/html");
    return doc.body.textContent || "";
  };

  pieChartConfig = (data, labels, opts = {}) => {
    const aspectRatio = "aspectRatio" in opts ? opts.aspectRatio : 2.2;
    const strippedLabels = labels.map((l) => this.stripHtml(l));

    return {
      type: PIE_CHART_TYPE,
      data: {
        datasets: [
          {
            data,
            backgroundColor: getColors(data.length),
          },
        ],
        labels: strippedLabels,
      },
      plugins: [this.htmlLegendPlugin],
      options: {
        responsive: true,
        aspectRatio,
        animation: { duration: 0 },
        plugins: {
          legend: {
            labels: {
              generateLabels() {
                return labels.map((text, index) => {
                  return {
                    fillStyle: getColors(data.length)[index],
                    text,
                    index,
                  };
                });
              },
            },
            display: false,
          },
          htmlLegend: {
            containerID: opts?.legendContainerId,
          },
        },
      },
    };
  };

  registerLegendElement = modifier((element) => {
    this.legendElement = element;
  });
  registerCanvasElement = modifier((element) => {
    this.canvasElement = element;
  });

  get canvasId() {
    return htmlSafe(`poll-results-chart-${this.args.id}`);
  }

  get legendId() {
    return htmlSafe(`poll-results-legend-${this.args.id}`);
  }

  @action
  async drawPie() {
    await loadScript("/javascripts/Chart.min.js");

    const data = this.args.options.mapBy("votes");
    const labels = this.args.options.mapBy("html");
    const config = this.pieChartConfig(data, labels, {
      legendContainerId: this.legendElement.id,
    });
    const el = this.canvasElement;
    // eslint-disable-next-line no-undef
    this._chart = new Chart(el.getContext("2d"), config);
  }

  <template>
    <div class="poll-results-chart">
      <canvas
        {{didInsert this.drawPie}}
        {{didInsert this.registerCanvasElement}}
        id={{this.canvasId}}
        class="poll-results-canvas"
      ></canvas>
      <ul
        {{didInsert this.registerLegendElement}}
        id={{this.legendId}}
        class="pie-chart-legends"
      >
      </ul>
    </div>
  </template>
}
