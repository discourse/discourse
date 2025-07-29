"use strict";

const EmberApp = require("ember-cli/lib/broccoli/ember-app");
const { compatBuild } = require("@embroider/compat");
// const { globSync } = require("glob");

// globSync("app/routes/**/*.js").forEach((file) => {
//   const route = file.match(/app\/routes\/(.*)\.js/)[1];
//   if (route === "application") {
//     return;
//   }
//   allRoutes.push(route);
// });
// console.log(allRoutes);

module.exports = async function (defaults) {
  let app = new EmberApp(defaults, {});
  const { buildOnce } = await import("@embroider/vite");

  return compatBuild(app, buildOnce, {
    splitAtRoutes: [/^[^.]+$/],
    staticAppPaths: [
      "static",
      "config",
      "form-kit",
      "lib",
      "mixins",
      "compat-modules",
    ],
  });
};
