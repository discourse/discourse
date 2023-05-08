import staticRouteBuilder from "discourse/lib/static-route-builder";

export default class RulesRoute extends staticRouteBuilder("rules") {
  // Rules and faq share the template (and the implicit controller)
  controllerName = "faq";
  templateName = "faq";
}
