"use strict";

const isCI = !!process.env.CI;
const isProduction = process.env.EMBER_ENV === "production";

const browsers = [
  "last 1 chrome version",
  "last 1 and_chr version",
  "last 1 firefox version",
  "last 1 and_ff version",
  "last 1 safari version",
  "safari 16.4",
  "ios_saf 16.4",
];

if (isCI || isProduction) {
  // Add older browsers here if needed
}

module.exports = {
  browsers,
};
