"use strict";

const isCI = !!process.env.CI;
const isProduction = process.env.EMBER_ENV === "production";

const browsers = [
  "last 1 Chrome versions",
  "last 1 Firefox versions",
  "last 1 Safari versions",
  "Safari 16.4",
];

if (isCI || isProduction) {
  // Add older browsers here if needed
}

module.exports = {
  browsers,
};
