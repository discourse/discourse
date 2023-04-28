import staticRouteBuilder from "discourse/lib/static-route-builder";

export default class ConductRoute extends staticRouteBuilder("conduct") {
  // Conduct and faq share the template (and the implicit controller)
  controllerName = "faq";
  templateName = "faq";
}
