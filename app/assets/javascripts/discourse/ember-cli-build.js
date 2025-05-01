"use strict";

const EmberApp = require("ember-cli/lib/broccoli/ember-app");
const { maybeEmbroider } = require("@embroider/test-setup");
const { globSync } = require("glob");

const allRoutes = [];
globSync("app/routes/**/*.js").forEach((file) => {
  const route = file.match(/app\/routes\/(.*)\.js/)[1];
  if (route === "application") {
    return;
  }
  allRoutes.push(route);
});
// console.log(allRoutes);

module.exports = function (defaults) {
  let app = new EmberApp(defaults, {});

  return maybeEmbroider(app, {
    staticComponents: true,
    staticHelpers: true,
    staticModifiers: true,
    splitAtRoutes: allRoutes,
    //[
    // /.*/,
    // "exception",
    // "exception-unknown",
    // "post",
    // "topic",
    // "topicBySlugOrId",
    // "newCategory",
    // "editCategory",
    // "discovery",
    // "groups",
    // "group",
    // "users",
    // "password-reset",
    // "account-created",
    // "activate-account",
    // "confirm-new-email",
    // "confirm-old-email",
    // "user",
    // "review",
    // "signup",
    // "login",
    // "email-login",
    // "second-factor-auth",
    // "associate-account",
    // "login-preferences",
    // "forgot-password",
    // "faq",
    // "guidelines",
    // "conduct",
    // "rules",
    // "tos",
    // "privacy",
    // "new-topic",
    // "new-message",
    // "new-invite",
    // "badges",
    // "full-page-search",
    // "tag",
    // "tags",
    // "tagGroups",
    // "invites",
    // "wizard",
    // "about",
    // ],
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
