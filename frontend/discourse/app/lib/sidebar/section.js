import { setOwner } from "@ember/owner";
import { service } from "@ember/service";
import { isPresent } from "@ember/utils";
import SidebarSectionForm from "discourse/components/modal/sidebar-section-form";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import { replaceUserSidebarSections } from "discourse/lib/sidebar/helpers";
import { extractDroppedWebLink } from "discourse/lib/sidebar/link-drop";
import SectionLink from "discourse/lib/sidebar/section-link";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import { unicodeSlugify } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";

export default class Section {
  @service currentUser;
  @service dialog;
  @service modal;
  @service router;

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

  /**
   * Whether the current user may change this section's links at all. A public
   * section is an admin's to edit; anyone else only owns their own.
   */
  get #canEditLinks() {
    return !this.section.public || this.currentUser?.admin;
  }

  /**
   * Dropping a link onto a section is a way of editing it, so it follows the
   * same permission. Offering a section that cannot be edited would leave an
   * admin dragging onto a public section and being handed a new one instead.
   *
   * A built-in section is excluded on top of that: its links come from the
   * server and are not the user's to add to.
   */
  get canAcceptLinkDrop() {
    return Boolean(this.#canEditLinks) && !this.section.section_type;
  }

  get headerActions() {
    if (this.#canEditLinks) {
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
  dropLink(source, linkDropIndex) {
    const link = extractDroppedWebLink(source);

    if (link) {
      return this.openForm(link, linkDropIndex);
    }
  }

  /**
   * Commits a dragged row's drop into this section: a drop from this very
   * section reorders it, one from another section transfers the link here.
   *
   * @param {Object} dragData - The drag source's payload: `sectionId`,
   *   `linkId`, and whether the source section is `public`.
   * @param {number|undefined} dropIndex - The measured drop offset;
   *   undefined appends.
   */
  @bind
  async moveLink(dragData, dropIndex) {
    const reordering = dragData.sectionId === this.section.id;
    // A drop right back into the gap it came from, on either side of the row,
    // changes nothing; decided before anything asks, so it never nags either.
    if (reordering && this.#reorderIsNoop(dragData.linkId, dropIndex)) {
      return;
    }

    // Editing a public section reaches everyone, so a drag that touches one,
    // on either end, gets the same confirmation the edit form gives it.
    if (dragData.public || this.section.public) {
      if (!(await this.#confirmPublicChange())) {
        return;
      }
    }

    if (reordering) {
      await this.#reorderLink(dragData, dropIndex);
    } else {
      await this.#transferLinkHere(dragData, dropIndex);
    }
  }

  #reorderIsNoop(linkId, dropIndex) {
    const fromIndex = this.#indexOfLink(linkId);
    const toIndex = dropIndex ?? this.links.length;
    return toIndex === fromIndex || toIndex === fromIndex + 1;
  }

  /**
   * Where a link sits right now. The drag payload only snapshots the list at
   * `dragstart`, and the drop may land in a different one.
   */
  #indexOfLink(linkId) {
    return this.links.findIndex((link) => link.id === linkId);
  }

  #confirmPublicChange() {
    return new Promise((resolve) => {
      this.dialog.yesNoConfirm({
        message: i18n("sidebar.sections.custom.update_public_confirm"),
        didConfirm: () => resolve(true),
        didCancel: () => resolve(false),
      });
    });
  }

  async #reorderLink({ linkId }, dropIndex) {
    const fromIndex = this.#indexOfLink(linkId);
    if (fromIndex === -1) {
      return;
    }

    const toIndex = dropIndex ?? this.links.length;
    const ids = this.links.map((link) => link.id);
    ids.splice(fromIndex, 1);
    ids.splice(toIndex > fromIndex ? toIndex - 1 : toIndex, 0, linkId);

    try {
      const response = await ajax(
        `/sidebar_sections/${this.section.id}/reorder`,
        { type: "PUT", data: { links_order: ids } }
      );
      replaceUserSidebarSections(this.currentUser, [response.sidebar_section]);
    } catch (error) {
      popupAjaxError(error);
    }
  }

  async #transferLinkHere({ sectionId, linkId }, dropIndex) {
    try {
      const response = await ajax(`/sidebar_sections/${sectionId}/move_link`, {
        type: "PUT",
        data: {
          link_id: linkId,
          target_section_id: this.section.id,
          position: dropIndex ?? this.links.length,
        },
      });
      replaceUserSidebarSections(this.currentUser, response.sidebar_sections);
    } catch (error) {
      popupAjaxError(error);
    }
  }
}
