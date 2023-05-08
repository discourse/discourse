import staticRouteBuilder from "discourse/lib/static-route-builder";

export default class PrivacyRoute extends staticRouteBuilder("privacy") {
  controllerName = "privacy";
  templateName = "privacy";
}
