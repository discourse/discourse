import staticRouteBuilder from "discourse/lib/static-route-builder";

export default class FaqRoute extends staticRouteBuilder("faq") {
  controllerName = "faq";
  templateName = "faq";
}
