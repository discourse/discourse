import { tracked } from "@glimmer/tracking";
import { bind } from "discourse-common/utils/decorators";
import RouteInfoHelper from "discourse/lib/sidebar/route-info-helper";
import { isTesting } from "discourse-common/config/environment";

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
    if (e.button === 0) {
      this.willDrag = true;
      setTimeout(
        () => {
          this.delayedStart(e);
        },
        isTesting() ? 0 : 300
      );
    }
  }
  delayedStart(e) {
    if (this.willDrag) {
      this.mouseY = e.screenY;
      this.linkDragCss = "drag";
      this.section.disable();
      this.drag = true;
    }
  }

  @bind
  didEndDrag() {
    this.linkDragCss = null;
    this.mouseY = null;
    this.section.enable();
    this.section.reorder();
    this.willDrag = false;
    this.drag = false;
  }

  @bind
  dragMove(e) {
    if (!this.drag) {
      return;
    }
    const currentMouseY = e.screenY;
    const distance = currentMouseY - this.mouseY;
    if (!this.linkHeight) {
      this.linkHeight = document.getElementsByClassName(
        "sidebar-section-link-wrapper"
      )[0].clientHeight;
    }
    if (distance >= this.linkHeight) {
      if (this.section.links.indexOf(this) !== this.section.links.length - 1) {
        this.section.moveLinkDown(this);
        this.mouseY = currentMouseY;
      }
    }
    if (distance <= -this.linkHeight) {
      if (this.section.links.indexOf(this) !== 0) {
        this.section.moveLinkUp(this);
        this.mouseY = currentMouseY;
      }
    }
  }
}
