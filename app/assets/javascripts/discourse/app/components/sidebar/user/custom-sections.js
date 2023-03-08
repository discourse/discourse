import Component from "@glimmer/component";
import showModal from "discourse/lib/show-modal";
import { inject as service } from "@ember/service";
import RouteInfoHelper from "discourse/lib/sidebar/route-info-helper";
import I18n from "I18n";
import { ajax } from "discourse/lib/ajax";
import { iconHTML } from "discourse-common/lib/icon-library";
import { htmlSafe } from "@ember/template";
import { bind } from "discourse-common/utils/decorators";
import { tracked } from "@glimmer/tracking";

class Section {
  @tracked dragCss;
  @tracked links;

  constructor(section, currentUser, router) {
    this.section = section;
    this.router = router;
    this.currentUser = currentUser;
    this.slug = section.slug;

    this.links = this.section.links.map((link) => {
      return new SectionLink(link, this, this.router);
    });
  }

  get decoratedTitle() {
    return this.section.public && this.currentUser.staff
      ? htmlSafe(`${iconHTML("globe")} ${this.section.title}`)
      : this.section.title;
  }

  get headerActions() {
    if (!this.section.public || this.currentUser.staff) {
      return [
        {
          action: () => {
            return showModal("sidebar-section-form", { model: this.section });
          },
          title: I18n.t("sidebar.sections.custom.edit"),
        },
      ];
    }
  }

  @bind
  disable() {
    this.dragCss = "disabled";
  }

  @bind
  enable() {
    this.dragCss = undefined;
  }

  @bind
  moveLinkDown(link) {
    const position = this.links.indexOf(link) + 1;
    this.links = this.links.removeObject(link);
    this.links.splice(position, 0, link);
  }

  @bind
  moveLinkUp(link) {
    const position = this.links.indexOf(link) - 1;
    this.links = this.links.removeObject(link);
    this.links.splice(position, 0, link);
  }
  @bind
  reorder() {
    return ajax(`/sidebar_sections/reorder`, {
      type: "POST",
      contentType: "application/json",
      dataType: "json",
      data: JSON.stringify({
        sidebar_section_id: this.section.id,
        links_order: this.links.map((link) => link.id),
      }),
    });
  }
}

class SectionLink {
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
  didEndDrag() {
    this.linkDragCss = null;
    this.mouseY = null;
    this.section.enable();
    this.section.reorder();
  }
  @bind
  dragMove(e) {
    if (!this.mouseY) {
      this.mouseY = e.screenY;
    }
    const distance = e.screenY - this.mouseY;
    if (!this.linkHeight) {
      this.linkHeight = e.srcElement.clientHeight;
    }
    if (distance > this.linkHeight) {
      if (this.section.links.indexOf(this) !== this.section.links.length - 1) {
        this.section.moveLinkDown(this);
        this.mouseY = e.screenY;
      }
    }
    if (distance < -this.linkHeight) {
      if (this.section.links.indexOf(this) !== 0) {
        this.section.moveLinkUp(this);
        this.mouseY = e.screenY;
      }
    }
    this.linkDragCss = "drag";
    this.section.disable();
  }
}

export default class SidebarUserCustomSections extends Component {
  @service currentUser;
  @service router;
  @service messageBus;

  constructor() {
    super(...arguments);
    this.messageBus.subscribe("/refresh-sidebar-sections", this._refresh);
  }

  willDestroy() {
    this.messageBus.unsubscribe("/refresh-sidebar-sections");
  }

  get sections() {
    return this.currentUser.sidebarSections.map((section) => {
      return new Section(section, this.currentUser, this.router);
    });
  }

  @bind
  _refresh() {
    return ajax("/sidebar_sections.json", {}).then((json) => {
      this.currentUser.set("sidebar_sections", json.sidebar_sections);
    });
  }
}
