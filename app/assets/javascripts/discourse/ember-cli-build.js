"use strict";

const EmberApp = require("ember-cli/lib/broccoli/ember-app");
const { compatBuild } = require("@embroider/compat");
// const { globSync } = require("glob");

const allRoutes = [];
// globSync("app/routes/**/*.js").forEach((file) => {
//   const route = file.match(/app\/routes\/(.*)\.js/)[1];
//   if (route === "application") {
//     return;
//   }
//   allRoutes.push(route);
// });
// console.log(allRoutes);

module.exports = function (defaults) {
  let app = new EmberApp(defaults, {});

  return compatBuild(app, {
    staticComponents: true,
    staticHelpers: true,
    staticModifiers: true,
    splitAtRoutes: allRoutes,
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
