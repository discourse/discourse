import Component from "@glimmer/component";
import { number } from "discourse/lib/formatter";
import { makeArray } from "discourse/lib/helpers";
import Chart from "./chart";

function getCSSColor(varName) {
  return getComputedStyle(document.documentElement)
    .getPropertyValue(varName)
    .trim();
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
  get chartConfig() {
    const { model } = this.args;
    const rows = makeArray(model.data);

    const labelProperty = model.labels?.[0]?.property || "key";
    const labels = rows.map((row) =>
      String(row[labelProperty] ?? row.key ?? row.x)
    );
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
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: {
          duration: prefersReducedMotion ? 0 : 300,
        },
        plugins: {
          legend: {
            display: true,
            position: "bottom",
            labels: {
              usePointStyle: true,
              pointStyle: "rectRounded",
              padding: 25,
              boxWidth: 10,
              boxHeight: 10,
              color: getCSSColor("--primary-high"),
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
              label: (tooltipItem) => {
                const value = tooltipItem.parsed;
                const total = tooltipItem.dataset.data.reduce(
                  (sum, v) => sum + v,
                  0
                );
                const pct = total > 0 ? ((value / total) * 100).toFixed(1) : 0;
                return ` ${tooltipItem.label}: ${number(value)} (${pct}%)`;
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
