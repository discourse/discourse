import { tracked } from "@glimmer/tracking";
import { bind } from "discourse-common/utils/decorators";
import RouteInfoHelper from "discourse/lib/sidebar/route-info-helper";

export default class SectionLink {
  @tracked linkDragCss;

  constructor({ external, icon, id, name, value }, section, router) {
    this.external = external;
    this.icon = icon;
    this.id = id;
    this.name = name;
    this.value = value;
    this.section = section;

    if (!this.external) {
      const routeInfoHelper = new RouteInfoHelper(router, value);
      this.route = routeInfoHelper.route;
      this.models = routeInfoHelper.models;
      this.query = routeInfoHelper.query;
    }
  }

  @bind
  didStartDrag(e) {
    this.mouseY = e.targetTouches ? e.targetTouches[0].screenY : e.screenY;
  }

  @bind
  didEndDrag() {
    this.linkDragCss = null;
    this.mouseY = null;
    this.section.enable();
    this.section.reorder();
  }

  @bind
  dragMove(e) {
    const currentMouseY = e.targetTouches
      ? e.targetTouches[0].screenY
      : e.screenY;
    const distance = currentMouseY - this.mouseY;
    if (!this.linkHeight) {
      this.linkHeight = document.getElementsByClassName(
        "sidebar-section-link-wrapper"
      )[0].clientHeight;
    }
    if (distance > this.linkHeight) {
      if (this.section.links.indexOf(this) !== this.section.links.length - 1) {
        this.section.moveLinkDown(this);
        this.mouseY = currentMouseY;
      }
    }
    if (distance < -this.linkHeight) {
      if (this.section.links.indexOf(this) !== 0) {
        this.section.moveLinkUp(this);
        this.mouseY = currentMouseY;
      }
    }
    this.linkDragCss = "drag";
    this.section.disable();
  }
}
