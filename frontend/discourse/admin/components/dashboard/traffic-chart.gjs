import Component from "@glimmer/component";
import Chart from "discourse/admin/components/chart";
import { i18n } from "discourse-i18n";

export default class DashboardTrafficChart extends Component {
  get chartConfig() {
    const pageviewSeries = this.args.traffic?.pageview_series ?? [];
    const points = pageviewSeries[0]?.data ?? [];
    const spansYears =
      this.args.traffic &&
      moment(this.args.startDate).year() !== moment(this.args.endDate).year();

    return {
      type: "bar",
      data: {
        labels: points.map((point) =>
          this.#formatBucketLabel(point, spansYears)
        ),
        datasets: pageviewSeries.map((series) => {
          const valuesByDate = new Map(
            series.data?.map((point) => [point.date, point.count || 0])
          );

          return {
            label: i18n(`admin.dashboard.site_traffic.series.${series.id}`),
            seriesId: series.id,
            stack: "site-traffic",
            data: points.map((point) => valuesByDate.get(point.date) ?? 0),
            backgroundColor: (context) =>
              this.#seriesColor(
                series.id,
                context?.chart?.canvas ?? document.documentElement
              ),
            borderWidth: 0,
            borderRadius: 0,
            maxBarThickness: 28,
            hidden: !series.default_visible,
          };
        }),
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        hover: { mode: "index", intersect: false },
        animation: {
          duration: window.matchMedia("(prefers-reduced-motion: reduce)")
            .matches
            ? 0
            : 200,
        },
        plugins: {
          legend: {
            display: pageviewSeries.length > 1,
            position: "top",
            align: "center",
            labels: {
              usePointStyle: true,
              pointStyle: "rectRounded",
              boxWidth: 10,
              boxHeight: 10,
              generateLabels: (chart) => {
                const textColor = this.#getCSSColor("--primary-high");

                return chart.data.datasets.map((dataset, index) => {
                  const visible = chart.isDatasetVisible(index);
                  const color = this.#seriesColor(
                    dataset.seriesId,
                    chart.canvas
                  );

                  return {
                    text: dataset.label,
                    fontColor: textColor,
                    fillStyle: visible ? color : "transparent",
                    strokeStyle: color,
                    lineWidth: 2,
                    hidden: false,
                    datasetIndex: index,
                    pointStyle: "rectRounded",
                  };
                });
              },
            },
          },
          tooltip: {
            mode: "index",
            intersect: false,
            backgroundColor: this.#getCSSColor("--primary"),
            titleColor: this.#getCSSColor("--secondary"),
            bodyColor: this.#getCSSColor("--secondary"),
            footerColor: this.#getCSSColor("--secondary"),
            cornerRadius: 8,
            boxPadding: 4,
            bodySpacing: 8,
            padding: 12,
            callbacks: {
              title: (items) =>
                this.#formatTooltipTitle(points[items[0].dataIndex]),
            },
          },
        },
        scales: {
          x: {
            stacked: true,
            offset: true,
            grid: { display: false },
            ticks: {
              color: this.#getCSSColor("--primary-medium"),
              font: { size: 11 },
              maxRotation: 0,
              autoSkip: true,
              padding: 8,
            },
          },
          y: {
            stacked: true,
            beginAtZero: true,
            grid: {
              color: this.#getCSSColor("--primary-very-low"),
            },
            ticks: {
              color: this.#getCSSColor("--primary-medium"),
              font: { size: 11 },
              padding: 8,
            },
          },
        },
      },
    };
  }

  #formatBucketLabel(point, spansYears) {
    const startDate = moment(point.date);
    return startDate.format(spansYears ? "D MMM YYYY" : "D MMM");
  }

  #formatTooltipTitle(point) {
    const startDate = moment(point.date);
    const endDate = moment(point.end_date || point.date);

    if (startDate.isSame(endDate, "day")) {
      return startDate.format("ddd, D MMM YYYY");
    }

    if (startDate.year() !== endDate.year()) {
      return `${startDate.format("D MMM YYYY")} - ${endDate.format("D MMM YYYY")}`;
    }

    return `${startDate.format("D MMM")} - ${endDate.format("D MMM YYYY")}`;
  }

  #seriesColor(id, element = document.documentElement) {
    const trafficElement = element.closest?.(".db-traffic") ?? element;

    return (
      this.#getCSSColor(this.#cssVarNameForSeries(id), trafficElement) ||
      this.#getCSSColor("--primary-med-or-secondary-med")
    );
  }

  #cssVarNameForSeries(id) {
    return `--db-traffic-series-${id.replaceAll("_", "-")}-color`;
  }

  #getCSSColor(varName, element = document.documentElement) {
    return getComputedStyle(element).getPropertyValue(varName).trim();
  }

  <template>
    <div class="db-section__traffic-chart">
      <Chart
        @chartConfig={{this.chartConfig}}
        @rebuildKey={{@traffic}}
        class="db-section__traffic-chart-canvas"
      />
    </div>
  </template>
}
