import { waitForPromise } from "@ember/test-waiters";

export default async function loadChartJS() {
  return (await waitForPromise(import("chart.js/auto"))).default;
}

export async function loadChartJSDatalabels() {
  return (await waitForPromise(import("chartjs-plugin-datalabels"))).default;
}
