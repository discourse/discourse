import { tracked } from "@glimmer/tracking";
import RouteInfoHelper from "discourse/lib/sidebar/route-info-helper";

export default class SectionLink {
  @tracked linkDragCss;

  constructor(
    { external, full_reload, icon, id, name, value },
    section,
    router
  ) {
    this.external = external;
    this.fullReload = full_reload;
    this.prefixValue = icon;
    this.id = id;
    this.name = name;
    this.text = name;
    this.value = value;
    this.section = section;
    this.withAnchor = value.match(/#\w+$/gi);

    if (!this.externalOrFullReload) {
      const routeInfoHelper = new RouteInfoHelper(router, value);

      this.route = routeInfoHelper.route;
      this.models = routeInfoHelper.models;
      this.query = routeInfoHelper.query;
    }
  }

  get shouldDisplay() {
    return true;
  }

  get externalOrFullReload() {
    return this.external || this.fullReload || this.withAnchor;
  }
}
