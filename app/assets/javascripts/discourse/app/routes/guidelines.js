import staticRouteBuilder from "discourse/lib/static-route-builder";

export default class GuidelinesRoute extends staticRouteBuilder("guidelines") {
  // Guidelines and faq share the template (and the implicit controller)
  controllerName = "faq";
  templateName = "faq";
}
