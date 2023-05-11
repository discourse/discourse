import I18n from "I18n";
import showModal from "discourse/lib/show-modal";
import { iconHTML } from "discourse-common/lib/icon-library";
import { htmlSafe } from "@ember/template";
import SectionLink from "discourse/lib/sidebar/section-link";
import { tracked } from "@glimmer/tracking";
import { bind } from "discourse-common/utils/decorators";
import { ajax } from "discourse/lib/ajax";

export default class Section {
  @tracked dragCss;
  @tracked links;

  constructor({ section, currentUser, router }) {
    this.section = section;
    this.router = router;
    this.currentUser = currentUser;
    this.slug = section.slug;

    this.links = this.section.links.map((link) => {
      return new SectionLink(link, this, this.router);
    });
  }

  get decoratedTitle() {
    return this.section.public && this.currentUser?.staff
      ? htmlSafe(`${iconHTML("globe")} ${this.section.title}`)
      : this.section.title;
  }

  get headerActions() {
    if (!this.section.public || this.currentUser?.staff) {
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

  get headerActionIcon() {
    return "pencil-alt";
  }

  @bind
  disable() {
    this.dragCss = "disabled";
  }

  @bind
  enable() {
    this.dragCss = null;
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
