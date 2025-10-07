export default async function loadChartJS() {
  return (await import("chart.js/auto")).default;
}

export async function loadChartJSDatalabels() {
  return (await import("chartjs-plugin-datalabels")).default;
}
