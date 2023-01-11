"use strict";

const progress = require("ember-cli/lib/utilities/heimdall-progress");

const CHECK_INTERVAL = 100;
const LOG_DUPLICATE_AFTER_DURATION = 5000;

const REPEAT_DUPLICATE_LOG_ITERATIONS =
  LOG_DUPLICATE_AFTER_DURATION / CHECK_INTERVAL;

// If running in CI mode, this addon will poll the current build node and log it.
// If the node runs for more than LOG_DUPLICATE_AFTER_DURATION, it will be logged again.
module.exports = {
  name: require("./package").name,

  preBuild() {
    if (this.project.ui.ci) {
      this._startOutput();
    }
  },

  outputReady() {
    this._stopOutput();
  },

  buildError() {
    this._stopOutput();
  },

  _startOutput() {
    this._discourseProgressLoggerInterval = setInterval(
      this._handleProgress.bind(this),
      CHECK_INTERVAL
    );
  },

  _handleProgress() {
    const text = progress();
    if (
      text === this._lastText &&
      this._sameOutputCount < REPEAT_DUPLICATE_LOG_ITERATIONS
    ) {
      this._sameOutputCount++;
    } else {
      this.project.ui.writeInfoLine("..." + (text ? `[${text}]` : "."));
      this._sameOutputCount = 0;
    }
    this._lastText = text;
  },

  _stopOutput() {
    clearInterval(this._discourseProgressLoggerInterval);
  },
};
