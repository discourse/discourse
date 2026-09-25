#!/usr/bin/env node

// Renders history.json as chart.svg: Brotli KiB loaded on first paint, per page, per step.

import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const here = path.dirname(fileURLToPath(import.meta.url));
const history = JSON.parse(
  readFileSync(path.join(here, "history.json"), "utf8")
);

const SERIES = [
  { key: "discovery", name: "Discovery page", color: "#2a78d6" },
  { key: "topic", name: "Topic page", color: "#eb6834" },
  { key: "boot", name: "Boot only (no route bundle)", color: "#1baf7a" },
];

const W = 1000;
const H = 600;
const M = { top: 96, right: 250, bottom: 190, left: 72 };
const plotW = W - M.left - M.right;
const plotH = H - M.top - M.bottom;

const kib = (row, key) => row[key].brotli / 1024;
const maxY =
  Math.ceil(
    Math.max(...history.flatMap((r) => SERIES.map((s) => kib(r, s.key)))) / 100
  ) * 100;
const x = (i) =>
  M.left +
  (history.length === 1 ? plotW / 2 : (i / (history.length - 1)) * plotW);
const y = (v) => M.top + plotH - (v / maxY) * plotH;
const esc = (s) =>
  s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/"/g, "&quot;");

const gridLines = [];
for (let v = 0; v <= maxY; v += 200) {
  gridLines.push(
    `<line x1="${M.left}" x2="${M.left + plotW}" y1="${y(v)}" y2="${y(v)}" stroke="#e6e5e1" stroke-width="1"/>`
  );
  gridLines.push(
    `<text x="${M.left - 10}" y="${y(v) + 4}" text-anchor="end" font-size="12" fill="#52514e">${v}</text>`
  );
}

const xLabels = history.map((row, i) => {
  const label =
    row.label.length > 34 ? row.label.slice(0, 33) + "…" : row.label;
  return `<text transform="translate(${x(i)},${M.top + plotH + 14}) rotate(30)" font-size="11" fill="#52514e"><title>${esc(row.label)}</title>${i + 1}. ${esc(label)}</text>`;
});

const lines = SERIES.map((s) => {
  const points = history.map(
    (row, i) => `${x(i).toFixed(1)},${y(kib(row, s.key)).toFixed(1)}`
  );
  const last = history.at(-1);
  const markers = history
    .map(
      (row, i) =>
        `<circle cx="${x(i).toFixed(1)}" cy="${y(kib(row, s.key)).toFixed(1)}" r="4" fill="${s.color}" stroke="#fcfcfb" stroke-width="2"><title>${esc(row.commit)} ${esc(row.label)}\n${s.name}: ${kib(row, s.key).toFixed(1)} KiB br (${(row[s.key].raw / 1024).toFixed(0)} KiB raw, ${row[s.key].chunks} chunks)</title></circle>`
    )
    .join("");
  return (
    `<polyline fill="none" stroke="${s.color}" stroke-width="2" stroke-linejoin="round" points="${points.join(" ")}"/>${markers}` +
    `<text x="${x(history.length - 1) + 10}" y="${y(kib(last, s.key)) + 4}" font-size="12" fill="#0b0b0b">${esc(s.name)} · ${kib(last, s.key).toFixed(0)} KiB</text>`
  );
});

const legend = SERIES.map(
  (s, i) =>
    `<g transform="translate(${M.left + i * 230},${M.top - 30})"><rect width="12" height="12" rx="2" fill="${s.color}"/><text x="18" y="10" font-size="12" fill="#0b0b0b">${esc(s.name)}</text></g>`
);

const first = history[0];
const last = history.at(-1);
const delta = (k) => (100 * (1 - kib(last, k) / kib(first, k))).toFixed(0);

const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" font-family="system-ui, -apple-system, Segoe UI, Helvetica, Arial, sans-serif">
<rect width="${W}" height="${H}" fill="#fcfcfb"/>
<text x="${M.left}" y="24" font-size="16" font-weight="600" fill="#0b0b0b">JavaScript loaded on initial boot (Brotli KiB, production build)</text>
<text x="${M.left}" y="44" font-size="12" fill="#52514e">Discovery −${delta("discovery")}% · Topic −${delta("topic")}% since baseline. Hover a point for the commit and sizes.</text>
${legend.join("\n")}
${gridLines.join("\n")}
<line x1="${M.left}" x2="${M.left + plotW}" y1="${y(0)}" y2="${y(0)}" stroke="#c3c2b7"/>
${lines.join("\n")}
${xLabels.join("\n")}
</svg>
`;

writeFileSync(path.join(here, "chart.svg"), svg);
console.log(`wrote chart.svg with ${history.length} steps`);
