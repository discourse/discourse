"use strict";

const EmberApp = require("ember-cli/lib/broccoli/ember-app");
const { compatBuild } = require("@embroider/compat");

// TODO
throw new Error("not used");

module.exports = async function (defaults) {
  let app = new EmberApp(defaults, {});
  const { buildOnce } = await import("@embroider/vite");

  return compatBuild(app, buildOnce, {
    staticInvokables: false,
    staticAppPaths: [
      "static",
      "admin",
      "select-kit",
      "float-kit",
      "truth-helpers",
      "dialog-holder",
    ],
  });
};
