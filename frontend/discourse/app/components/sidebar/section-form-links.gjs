import Component from "@glimmer/component";
import SectionFormLink from "discourse/components/sidebar/section-form-link";
import { removeValueFromArray } from "discourse/lib/array-tools";
import { bind } from "discourse/lib/decorators";
import { eq, has } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

/**
 * The section form's links region as it renders without
 * `enable_new_reordering_controls`: a hand-rolled table whose rows carry their
 * own drag handlers.
 *
 * The arrays arrive by reference and are mutated in place, which is what the
 * form's own tracking already relies on.
 *
 * TODO (ui-kit-reorderable-list-cleanup) delete this file once the change
 * ships; `sidebar-section-form-links-reorderable.gjs` replaces it.
 */
export default class SidebarSectionFormLinks extends Component {
  // Not a # private: the legacy decorator transform cannot compile a class
  // that mixes a decorated member with private fields, and it fails the build
  // rather than the lint.
  draggedLink;

  get lastActiveLinkIndex() {
    return this.args.activeLinks.length - 1;
  }

  get lastActiveSecondaryLinkIndex() {
    return (this.args.activeSecondaryLinks?.length ?? 0) - 1;
  }

  @bind
  setDraggedLink(link) {
    this.draggedLink = link;
  }

  @bind
  reorder(targetLink, above) {
    if (this.draggedLink === targetLink) {
      return;
    }

    const source = this.draggedLink.isPrimary
      ? this.args.links
      : this.args.secondaryLinks;
    const destination = targetLink.isPrimary
      ? this.args.links
      : this.args.secondaryLinks;

    // Nothing to insert next to, so leave both arrays untouched rather than
    // removing the link and dropping it at an arbitrary offset.
    if (!destination.includes(targetLink)) {
      return;
    }

    removeValueFromArray(source, this.draggedLink);

    // Read after the removal: within one segment the two arrays are the same
    // one, so a pre-removal index would be off by one when dragging downwards.
    const toPosition = destination.indexOf(targetLink);

    this.draggedLink.segment = targetLink.isPrimary ? "primary" : "secondary";

    destination.splice(
      above ? toPosition : toPosition + 1,
      0,
      this.draggedLink
    );
  }

  <template>
    <div
      role="table"
      aria-labelledby="section-links-label"
      aria-rowcount={{@activeLinks.length}}
      class="sidebar-section-form__links-wrapper"
    >

      <div class="row-wrapper header" role="row">
        <div class="input-group link-icon" role="columnheader" aria-sort="none">
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <label>{{i18n "sidebar.sections.custom.links.icon.label"}}</label>
        </div>

        <div class="input-group link-name" role="columnheader" aria-sort="none">
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <label>{{i18n "sidebar.sections.custom.links.name.label"}}</label>
        </div>

        <div class="input-group link-url" role="columnheader" aria-sort="none">
          {{! eslint-disable-next-line ember/template-no-nested-interactive }}
          <label>{{i18n "sidebar.sections.custom.links.value.label"}}</label>
        </div>
      </div>

      {{#each @activeLinks key="objectId" as |link index|}}
        <SectionFormLink
          @link={{link}}
          @index={{index}}
          @lastIndex={{this.lastActiveLinkIndex}}
          @focusNameInput={{eq link.objectId @initialFocusLinkObjectId}}
          @duplicateValue={{has @duplicateLinkObjectIds link.objectId}}
          @deleteLink={{@deleteLink}}
          @reorderCallback={{this.reorder}}
          @setDraggedLinkCallback={{this.setDraggedLink}}
        />
      {{/each}}

    </div>
    <DButton
      @action={{@addLink}}
      @title="sidebar.sections.custom.links.add"
      @icon="plus"
      @label="sidebar.sections.custom.links.add"
      @ariaLabel="sidebar.sections.custom.links.add"
      class="btn-flat btn-text add-link"
    />

    {{#if @sectionType}}
      <hr />
      <h3>{{i18n "sidebar.sections.custom.more_menu"}}</h3>
      {{#each @activeSecondaryLinks key="objectId" as |link index|}}
        <SectionFormLink
          @link={{link}}
          @index={{index}}
          @lastIndex={{this.lastActiveSecondaryLinkIndex}}
          @duplicateValue={{has @duplicateLinkObjectIds link.objectId}}
          @deleteLink={{@deleteLink}}
          @reorderCallback={{this.reorder}}
          @setDraggedLinkCallback={{this.setDraggedLink}}
        />
      {{/each}}
      <DButton
        @action={{@addSecondaryLink}}
        @title="sidebar.sections.custom.links.add"
        @icon="plus"
        @label="sidebar.sections.custom.links.add"
        @ariaLabel="sidebar.sections.custom.links.add"
        class="btn-flat btn-text add-link"
      />
    {{/if}}
  </template>
}
