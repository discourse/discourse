"use strict";

module.exports = {
  eslint: {
    daysToDecay: {
      warn: 365,
      // To start, until existing todos are deal with, Infinity is a good place to start -- least disruption
      // Once lints are dealt with, this could be set to 60 days, for example
      // (as in the README)
      // https://github.com/lint-todo/eslint-formatter-todo
      error: Infinity,
    },
  },
  "ember-template-lint": {
    daysToDecay: {
      warn: 365,
      error: Infinity,
    },
  },
};
