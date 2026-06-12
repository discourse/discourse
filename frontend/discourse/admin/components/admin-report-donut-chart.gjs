import Component from "@glimmer/component";
import { service } from "@ember/service";
import { makeArray } from "discourse/lib/helpers";
import Chart from "./chart";

function getCSSColor(varName) {
  return getComputedStyle(document.documentElement)
    .getPropertyValue(varName)
    .trim();
}

function buildLegendIcon(color, isVisible, size = 16) {
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d");

  const borderWidth = 2;
  const half = borderWidth / 2;
  ctx.strokeStyle = color;
  ctx.lineWidth = borderWidth;
  ctx.beginPath();
  ctx.roundRect(half, half, size - borderWidth, size - borderWidth, 4);
  ctx.stroke();

  if (isVisible) {
    const inset = 4;
    ctx.fillStyle = color;
    ctx.beginPath();
    ctx.roundRect(inset, inset, size - inset * 2, size - inset * 2, 2);
    ctx.fill();
  }

  return canvas;
}

function hexToRgba(hex, alpha) {
  const r = parseInt(hex.slice(1, 3), 16);
  const g = parseInt(hex.slice(3, 5), 16);
  const b = parseInt(hex.slice(5, 7), 16);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

export const gradientPlugin = {
  id: "gradientPlugin",
  beforeDatasetsDraw(chart) {
    const { ctx } = chart;
    chart.data.datasets.forEach((dataset, datasetIndex) => {
      if (!dataset._baseColor) {
        return;
      }
      const meta = chart.getDatasetMeta(datasetIndex);
      if (!meta.data.length) {
        return;
      }

      const gradients = meta.data.map((bar) => {
        const { x, y, width, base } = bar.getProps(
          ["x", "y", "width", "base"],
          true
        );
        const gradient = ctx.createLinearGradient(
          x - width / 2,
          y,
          x + width / 2,
          base
        );
        gradient.addColorStop(0, dataset._baseColor);
        gradient.addColorStop(1, hexToRgba(dataset._baseColor, 0.7));
        return gradient;
      });

      dataset.backgroundColor = gradients;
    });
  },
};

export default class AdminReportDonutChart extends Component {
  @service capabilities;

  get currentData() {
    const { model, filterType = "role" } = this.args;
    const data = filterType === "status" ? model.data_status : model.data_role;
    return data || model.data || [];
  }

  get chartConfig() {
    const { model } = this.args;
    const rows = makeArray(this.currentData);

    const labelProperty = model.labels?.[0]?.property || "key";
    const labels = rows.map((row) => {
      const labelText = String(row[labelProperty] ?? row.key ?? row.x);
      const value = row.y;
      return `${labelText} (${value})`;
    });
    const values = rows.map((row) => row.y);
    const colors = rows.map((row) => row.color);

    const prefersReducedMotion = window.matchMedia(
      "(prefers-reduced-motion: reduce)"
    ).matches;

    return {
      type: "doughnut",
      data: {
        labels,
        datasets: [
          {
            data: values,
            backgroundColor: colors,
            hoverOffset: prefersReducedMotion ? 0 : 16,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        onResize: (chart) => {
          if (this.capabilities.viewport.sm) {
            chart.options.plugins.legend.position = "right";
          } else {
            chart.options.plugins.legend.position = "bottom";
          }
        },
        animation: {
          duration: prefersReducedMotion ? 0 : 300,
        },
        layout: {
          padding: 16,
        },
        plugins: {
          legend: {
            display: true,
            align: "left",
            labels: {
              generateLabels: (chart) => {
                const dataset = chart.data.datasets[0];
                const textColor = getCSSColor("--primary-high");
                return chart.data.labels.map((label, i) => {
                  const isVisible = chart.getDataVisibility(i);
                  const color = dataset.backgroundColor[i];
                  return {
                    text: label,
                    fontColor: textColor,
                    pointStyle: buildLegendIcon(color, isVisible),
                    hidden: false,
                    index: i,
                  };
                });
              },
              usePointStyle: true,
              padding: 25,
              boxWidth: 16,
              boxHeight: 16,
              font: {
                size: 16,
              },
            },
          },
          tooltip: {
            backgroundColor: getCSSColor("--primary"),
            padding: {
              left: 20,
              right: 20,
              top: 12,
              bottom: 12,
            },
            bodySpacing: 8,
            cornerRadius: 8,
            boxPadding: 4,
            callbacks: {
              title: () => null,
              label: (tooltipItem) => {
                const value = tooltipItem.parsed;
                const total = tooltipItem.dataset.data.reduce(
                  (sum, v) => sum + v,
                  0
                );
                const pct = total > 0 ? ((value / total) * 100).toFixed(1) : 0;
                return `${tooltipItem.label} – ${pct}%`;
              },
            },
          },
        },
      },
    };
  }

  <template>
    <Chart
      @chartConfig={{this.chartConfig}}
      class="admin-report-chart admin-report-donut-chart"
    />
  </template>
}
