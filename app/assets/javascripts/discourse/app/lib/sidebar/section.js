import { tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { isPresent } from "@ember/utils";
import SidebarSectionForm from "discourse/components/modal/sidebar-section-form";
import { ajax } from "discourse/lib/ajax";
import { bind } from "discourse/lib/decorators";
import SectionLink from "discourse/lib/sidebar/section-link";
import { unicodeSlugify } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class Section {
  @service currentUser;
  @service modal;
  @service router;

  @tracked dragCss;
  @tracked links;

  constructor({ section, owner }) {
    setOwner(this, owner);

    this.section = section;
    this.slug = isPresent(section.slug)
      ? section.slug
      : unicodeSlugify(section.title);

    this.links = this.section.links.map((link) => {
      return new SectionLink(link, this, this.router);
    });
  }

  get decoratedTitle() {
    return this.section.title;
  }

  get indicatePublic() {
    return this.section.public && this.currentUser?.staff;
  }

  get headerActions() {
    if (!this.section.public || this.currentUser?.admin) {
      return [
        {
          action: () => {
            return this.modal.show(SidebarSectionForm, {
              model: this,
            });
          },
          title: i18n("sidebar.sections.custom.edit"),
        },
      ];
    }
  }

  get headerActionIcon() {
    return "pencil";
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
