import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import loadScript from "discourse/lib/load-script";
import I18n, { i18n } from "discourse-i18n";

const oneDay = 86400000; // day in milliseconds

const now = new Date();
const startOfDay = Date.UTC(
  now.getUTCFullYear(),
  now.getUTCMonth(),
  now.getUTCDate()
);

function fillMissingDates(data) {
  const filledData = [];
  let currentDate = data[0].x;

  for (let i = 0; i < data.length; i++) {
    while (currentDate < data[i].x) {
      filledData.push({ x: currentDate, y: 0 });
      currentDate += oneDay;
    }
    filledData.push(data[i]);
    currentDate = data[i].x + oneDay;
  }

  return filledData;
}

function weightedMovingAverage(data, period = 3) {
  const weights = Array.from({ length: period }, (_, i) => i + 1);
  const weightSum = weights.reduce((a, b) => a + b, 0);
  let result = [];

  for (let i = 0; i < data.length; i++) {
    if (i < period - 1) {
      result.push(null);
      continue;
    }

    let weightedSum = 0;
    for (let j = 0; j < period; j++) {
      weightedSum += data[i - j].y * weights[j];
    }

    result.push(Math.round(weightedSum / weightSum));
  }

  return result;
}

function predictTodaysViews(data) {
  const movingAvg = weightedMovingAverage(data);
  const lastMovingAvg = movingAvg[movingAvg.length - 1];
  const currentViews = data[data.length - 1].y;
  const currentTimeUTC = Date.now() + now.getTimezoneOffset() * 60 * 1000;
  const elapsedTime = (currentTimeUTC - startOfDay) / oneDay; // amount of day passed
  let adjustedPrediction = lastMovingAvg;

  if (currentViews >= lastMovingAvg) {
    // If higher than the average prediction, extrapolate
    adjustedPrediction =
      currentViews + (currentViews - lastMovingAvg) * (1 - elapsedTime);
  } else {
    // If views are lower than the average, adjust towards average
    adjustedPrediction = currentViews + lastMovingAvg * (1 - elapsedTime);
  }
  return Math.round(Math.max(adjustedPrediction, currentViews)); // never lower than actual data
}

export default class TopicViewsChart extends Component {
  chart = null;
  noData = false;

  @action
  async renderChart(element) {
    await loadScript("/javascripts/Chart.min.js");

    if (!this.args.views?.stats || this.args.views?.stats?.length === 0) {
      this.noData = true;
      return;
    }

    let data = this.args.views.stats.map((item) => ({
      x: new Date(`${item.viewed_at}T00:00:00Z`).getTime(), // Use UTC time
      y: item.views,
    }));

    data = fillMissingDates(data);

    const lastDay = data[data.length - 1];

    const predictedViews = predictTodaysViews(data);
    const predictedDataPoint = {
      x: lastDay.x,
      y: predictedViews,
    };

    // remove current day's actual point, we'll replace with prediction
    data = data.slice(0, data.length - 1);
    // Add predicted data point
    data.push(predictedDataPoint);

    const context = element.getContext("2d");

    const xMin = data[0].x;
    const xMax = lastDay.x;

    const topicMapElement = document.querySelector(".topic-map");

    // grab colors from CSS
    const lineColor =
      getComputedStyle(topicMapElement).getPropertyValue("--chart-line-color");
    const pointColor = getComputedStyle(topicMapElement).getPropertyValue(
      "--chart-point-color"
    );
    const predictionColor = getComputedStyle(topicMapElement).getPropertyValue(
      "--chart-prediction-color"
    );

    if (this.chart) {
      this.chart.destroy();
    }

    this.chart = new window.Chart(context, {
      type: "line",
      data: {
        datasets: [
          {
            label: "Views",
            data: data.slice(0, -1),
            showLine: true,
            borderColor: pointColor,
            backgroundColor: lineColor,
            pointBackgroundColor: pointColor,
          },
          {
            label: "Predicted Views",
            data: [data[data.length - 2], data[data.length - 1]],
            showLine: true,
            borderDash: [5, 5],
            borderColor: predictionColor,
            backgroundColor: predictionColor,
            pointBackgroundColor: predictionColor,
          },
        ],
      },
      options: {
        scales: {
          x: {
            type: "linear",
            position: "bottom",
            min: xMin,
            max: xMax,
            ticks: {
              autoSkip: false,
              stepSize: oneDay,
              maxTicksLimit: 15,
              callback: function (value) {
                const date = new Date(value + oneDay);
                return date.toLocaleDateString(I18n.currentBcp47Locale, {
                  month: "2-digit",
                  day: "2-digit",
                });
              },
            },
          },
          y: {
            beginAtZero: true,
            ticks: {
              callback: function (value) {
                return value;
              },
            },
          },
        },
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            callbacks: {
              title: function (tooltipItem) {
                let date = new Date(tooltipItem[0]?.parsed?.x + oneDay);
                if (tooltipItem.length === 0) {
                  const today = new Date();
                  date = today.getUTCDate();
                }
                return date.toLocaleDateString(I18n.currentBcp47Locale, {
                  month: "2-digit",
                  day: "2-digit",
                  year: "numeric",
                });
              },
              label: function (tooltipItem) {
                const label =
                  tooltipItem?.parsed?.x === startOfDay
                    ? i18n("topic_map.predicted_views")
                    : i18n("topic_map.views");

                return `${label}: ${tooltipItem?.parsed?.y}`;
              },
            },
            filter: function (tooltipItem) {
              return !(
                tooltipItem?.parsed?.x === startOfDay - oneDay &&
                tooltipItem?.datasetIndex === 1
              );
            },
          },
        },
      },
    });
  }

  <template>
    {{#if this.noData}}
      {{i18n "topic_map.chart_error"}}
    {{else}}
      <canvas {{didInsert this.renderChart}}></canvas>
      <div class="view-explainer">{{i18n "topic_map.view_explainer"}}</div>
    {{/if}}
  </template>
}
