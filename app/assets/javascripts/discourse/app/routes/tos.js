import staticRouteBuilder from "discourse/lib/static-route-builder";

export default class TosRoute extends staticRouteBuilder("tos") {
  controllerName = "tos";
  templateName = "tos";
}
