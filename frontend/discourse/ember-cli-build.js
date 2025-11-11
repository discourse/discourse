"use strict";

const EmberApp = require("ember-cli/lib/broccoli/ember-app");
const { compatBuild } = require("@embroider/compat");
// const { globSync } = require("glob");
//   if (route === "application") {
//     return;
//
// })

const allRoutes = [
  "about",
  "account-created",
  "application",
  "badges",
  "composer",
  "confirm-new-email",
  "confirm-old-email",
  "discovery",
  "email-login",
  // "exception",
  "full-page-search",
  "group",
  "groups",
  "invites",
  "login",
  "password-reset",
  "preferences",
  "review",
  "second-factor-auth",
  "signup",
  "tag-groups",
  "tag",
  "tags",
  "topic",
  // "user-activity",
  "user-invited",
  "user-notifications",
  "user-posts",
  "user-private-messages",
  "user-topics-list",
  // "user", // Many @controller user
  "users",
  "activate-account",
  "app-route-map",
  "associate-account",
  "build-category-route",
  "build-group-messages-route",
  "build-private-messages-group-route",
  "build-private-messages-route",
  "build-topic-route",
  "conduct",
  "discourse",
  "exception-unknown",
  "faq",
  "forgot-password",
  "guidelines",
  "new-invite",
  "new-message",
  "new-topic",
  "post",
  "posts",
  "privacy",
  "restricted-user",
  "rules",
  "topic-by-slug-or-id",
  "tos",
  "unknown",
  "user-activity-stream",
  "user-topic-list",
  "wizard",
  "loading",
  "login-preferences",
  "selected-posts",
];
module.exports = async function (defaults) {
  let app = new EmberApp(defaults, {});
  const { buildOnce } = await import("@embroider/vite");

  return compatBuild(app, buildOnce, {
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
