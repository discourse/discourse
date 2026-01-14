import { waitForPromise } from "@ember/test-waiters";

export default async function loadChartJS() {
  await waitForPromise(import("chartjs-adapter-moment"));
  return (await waitForPromise(import("chart.js/auto"))).default;
}

/**
 *
 * @returns {import("chart.js").Plugin}
 */
export async function loadChartJSDatalabels() {
  return (await waitForPromise(import("chartjs-plugin-datalabels"))).default;
}
