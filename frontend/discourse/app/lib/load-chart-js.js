import { waitForPromise } from "@ember/test-waiters";

export default async function loadChartJS() {
  return (await waitForPromise(import("discourse/static/chart-js-bundle")))
    .Chart;
}

/**
 * @returns {Promise<import("chart.js").Plugin>}
 */
export async function loadChartJSDatalabels() {
  return (await waitForPromise(import("discourse/static/chart-js-bundle")))
    .ChartDataLabels;
}

/**
 * @returns {Promise<typeof import("chart.js/helpers").getHoverColor>}
 */
export async function loadChartJSGetHoverColor() {
  return (await waitForPromise(import("discourse/static/chart-js-bundle")))
    .getHoverColor;
}
