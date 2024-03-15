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
    this.withAnchor = /#\w+$/i.test(value);

    if (!this.externalOrFullReload) {
      const { route, models, query } = new RouteInfoHelper(router, value);
      this.route = route;
      this.models = models;
      this.query = query;
    }
  }

  get shouldDisplay() {
    return true;
  }

  get externalOrFullReload() {
    return this.external || this.fullReload || this.withAnchor;
  }
}
