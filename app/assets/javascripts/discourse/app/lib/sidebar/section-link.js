import { tracked } from "@glimmer/tracking";
import { bind } from "discourse-common/utils/decorators";
import RouteInfoHelper from "discourse/lib/sidebar/route-info-helper";
import discourseLater from "discourse-common/lib/later";

const TOUCH_SCREEN_DELAY = 300;
const MOUSE_DELAY = 250;

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

  @bind
  didStartDrag(event) {
    // 0 represents left button of the mouse
    if (event.button === 0 || event.targetTouches) {
      this.startMouseY = this.#calcMouseY(event);
      this.willDrag = true;

      discourseLater(
        () => {
          this.delayedStart(event);
        },
        event.targetTouches ? TOUCH_SCREEN_DELAY : MOUSE_DELAY
      );
    }
  }

  delayedStart(event) {
    if (this.willDrag) {
      const currentMouseY = this.#calcMouseY(event);

      if (currentMouseY === this.startMouseY) {
        event.stopPropagation();
        event.preventDefault();
        this.mouseY = this.#calcMouseY(event);
        this.linkDragCss = "drag";
        this.section.disable();
        this.drag = true;
      }
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
  dragMove(event) {
    const moveMouseY = this.#calcMouseY(event);

    if (this.willDrag && moveMouseY !== this.startMouseY && !this.drag) {
      /**
       * If mouse position is different, it means that it is a scroll and not drag and drop action.
       * In that case, we want to do nothing and keep original behaviour.
       */
      this.willDrag = false;
      return;
    } else {
      /**
       * Otherwise, event propagation should be stopped as we have our own handler for drag and drop.
       */
      event.stopPropagation();
      event.preventDefault();
    }

    this.startMouseY = moveMouseY;

    if (!this.drag) {
      return;
    }

    const currentMouseY = this.#calcMouseY(event);
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

  #calcMouseY(event) {
    return Math.round(
      event.targetTouches ? event.targetTouches[0].clientY : event.y
    );
  }
}
