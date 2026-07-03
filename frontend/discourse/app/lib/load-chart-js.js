import { waitForPromise } from "@ember/test-waiters";

export default async function loadChartJS() {
  return (await waitForPromise(import("discourse/static/chart-js-bundle")))
    .Chart;
}

/**
 *
 * @returns {import("chart.js").Plugin}
 */
export async function loadChartJSDatalabels() {
  return (await waitForPromise(import("discourse/static/chart-js-bundle")))
    .ChartDataLabels;
}
