import { tracked } from "@glimmer/tracking";
import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { isPresent } from "@ember/utils";
import SidebarSectionForm from "discourse/components/modal/sidebar-section-form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { extractDroppedWebLink } from "discourse/lib/sidebar/link-drop";
import SectionLink from "discourse/lib/sidebar/section-link";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import { unicodeSlugify } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class Section {
  @service currentUser;
  @service modal;
  @service router;

  @tracked dragCss;
  @autoTrackedArray links;

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

  get canAcceptLinkDrop() {
    return this.section.public === false && !this.section.section_type;
  }

  async openForm(link, linkDropIndex) {
    const json = await ajax(`/sidebar_sections/${this.section.id}.json`).catch(
      popupAjaxError
    );

    if (!json) {
      return;
    }

    const section = json.sidebar_section;
    let focusLinkIndex;

    if (link) {
      const insertionIndex = Math.min(
        Math.max(linkDropIndex ?? section.links.length, 0),
        section.links.length
      );
      focusLinkIndex = section.links
        .slice(0, insertionIndex)
        .filter((sectionLink) => sectionLink.segment === "primary").length;
      section.links.splice(insertionIndex, 0, {
        ...link,
        locale: section.locale,
      });
    }

    return this.modal.show(SidebarSectionForm, {
      model: {
        focusLinkIndex,
        hideSectionHeader: this.hideSectionHeader,
        section,
      },
    });
  }

  @bind
  dropLink(dataTransfer, linkDropIndex) {
    const link = extractDroppedWebLink(dataTransfer);

    if (link) {
      return this.openForm(link, linkDropIndex);
    }
  }

  get headerActions() {
    if (!this.section.public || this.currentUser?.admin) {
      return [
        {
          action: () => this.openForm(),
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
    const position = this.links.indexOf(link);
    this.links.splice(position, 1);
    this.links.splice(position + 1, 0, link);
  }

  @bind
  moveLinkUp(link) {
    const position = this.links.indexOf(link);
    this.links.splice(position, 1);
    this.links.splice(position - 1, 0, link);
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
