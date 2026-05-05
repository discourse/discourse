/* eslint-disable no-console */
import { waitForPromise } from "@ember/test-waiters";

export default async function loadChartJS() {
  console.log("[loadChartJS] before adapter import");
  const adapterPromise = import("chartjs-adapter-moment");
  adapterPromise.then(
    () => console.log("[loadChartJS] adapter resolved"),
    (e) => console.log("[loadChartJS] adapter rejected", e)
  );
  await waitForPromise(adapterPromise);

  console.log("[loadChartJS] before auto import");
  const autoPromise = import("chart.js/auto");
  autoPromise.then(
    () => console.log("[loadChartJS] auto resolved"),
    (e) => console.log("[loadChartJS] auto rejected", e)
  );
  return (await waitForPromise(autoPromise)).default;
}

/**
 *
 * @returns {import("chart.js").Plugin}
 */
export async function loadChartJSDatalabels() {
  console.log("[loadChartJSDatalabels] before import");
  const p = import("chartjs-plugin-datalabels");
  p.then(
    () => console.log("[loadChartJSDatalabels] resolved"),
    (e) => console.log("[loadChartJSDatalabels] rejected", e)
  );
  return (await waitForPromise(p)).default;
}
