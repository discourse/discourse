"use strict";

const isCI = !!process.env.CI;
const isProduction = process.env.EMBER_ENV === "production";

const browsers = [
  "last 1 Chrome versions",
  "last 1 Firefox versions",
  "last 1 Safari versions",
];

if (isCI || isProduction) {
  browsers.push("Safari 15");
}

module.exports = {
  browsers,
};
