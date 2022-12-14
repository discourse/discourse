import staticRouteBuilder from "discourse/lib/static-route-builder";

export default class GuidelinesRoute extends staticRouteBuilder("guidelines") {
  controllerName = "faq";
  templateName = "faq";
}
