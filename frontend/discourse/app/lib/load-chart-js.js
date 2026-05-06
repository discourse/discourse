/* eslint-disable no-console */
import { waitForPromise } from "@ember/test-waiters";

function logResourceTiming(tag, urlSubstring) {
  const entries = performance
    .getEntriesByType("resource")
    .filter((e) => e.name.includes(urlSubstring));
  if (entries.length === 0) {
    console.log(`[${tag}] no resource timing entry for ${urlSubstring}`);
    return;
  }
  for (const e of entries) {
    console.log(
      `[${tag}] ${e.name.split("/").pop()} ` +
        `start=${e.startTime.toFixed(0)} ` +
        `requestStart=${e.requestStart.toFixed(0)} ` +
        `responseStart=${e.responseStart.toFixed(0)} ` +
        `responseEnd=${e.responseEnd.toFixed(0)} ` +
        `duration=${e.duration.toFixed(0)} ` +
        `transferSize=${e.transferSize}`
    );
  }
}

export default async function loadChartJS() {
  const t0 = performance.now();
  console.log(`[loadChartJS] before adapter import t=${t0.toFixed(0)}`);
  const adapterPromise = import("chartjs-adapter-moment");
  adapterPromise.then(
    () => {
      const t = performance.now();
      console.log(
        `[loadChartJS] adapter resolved t=${t.toFixed(0)} elapsed=${(t - t0).toFixed(0)}ms`
      );
      logResourceTiming("loadChartJS-adapter", "chartjs-adapter-moment");
    },
    (e) => console.log("[loadChartJS] adapter rejected", e)
  );
  await waitForPromise(adapterPromise);

  const t1 = performance.now();
  console.log(`[loadChartJS] before auto import t=${t1.toFixed(0)}`);
  const autoPromise = import("chart.js/auto");
  autoPromise.then(
    () => {
      const t = performance.now();
      console.log(
        `[loadChartJS] auto resolved t=${t.toFixed(0)} elapsed=${(t - t1).toFixed(0)}ms`
      );
      logResourceTiming("loadChartJS-auto", "auto-");
      logResourceTiming("loadChartJS-chart", "chart-");
    },
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
