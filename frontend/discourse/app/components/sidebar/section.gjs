import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { next } from "@ember/runloop";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import DMenu from "discourse/float-kit/components/d-menu";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { bind } from "discourse/lib/decorators";
import {
  getCollapsedSidebarSectionKey,
  getSidebarSectionContentId,
} from "discourse/lib/sidebar/helpers";
import {
  WEB_LINK_ADOPTION,
  WEB_LINK_KINDS,
  webLinkPayload,
} from "discourse/lib/sidebar/link-drop";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropExternalTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
import dDragAndDropTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-target";
import dDragDwell from "discourse/ui-kit/modifiers/d-drag-dwell";
import { i18n } from "discourse-i18n";
import SectionHeader from "./section-header";

export default class SidebarSection extends Component {
  @service keyValueStore;
  @service router;
  @service sidebarState;

  @tracked linkDropActive = false;
  @tracked linkDropIndex;
  @tracked linkDropLinkCount = 0;

  sidebarSectionContentId = getSidebarSectionContentId(this.args.sectionName);
  collapsedSidebarSectionKey = getCollapsedSidebarSectionKey(
    this.args.sectionName
  );

  /** Whether this section is only open because a drag asked it to be. */
  #openedForDrag = false;

  constructor() {
    super(...arguments);

    this.router.on("routeDidChange", this, this.expandIfActive);
  }

  willDestroy() {
    super.willDestroy(...arguments);

    this.#collapseIfOpenedForDrag();
    this.router.off("routeDidChange", this, this.expandIfActive);

    this.args.willDestroy?.();
  }

  get isCollapsed() {
    if (!this.args.collapsable) {
      return false;
    }

    if (
      this.keyValueStore.getItem(this.collapsedSidebarSectionKey) === undefined
    ) {
      return this.args.collapsedByDefault;
    }

    return (
      this.keyValueStore.getItem(this.collapsedSidebarSectionKey) === "true"
    );
  }

  get isActive() {
    return !!this.args.activeLink;
  }

  get activeExpanded() {
    return this.sidebarState.activeExpandedSections.has(this.args.sectionName);
  }

  set activeExpanded(value) {
    if (value) {
      this.sidebarState.activeExpandedSections.add(this.args.sectionName);
    } else {
      this.sidebarState.activeExpandedSections.delete(this.args.sectionName);
    }
  }

  @bind
  setExpandedState() {
    if (!isEmpty(this.sidebarState.filter)) {
      return;
    }

    // initialize the collapsed/expanded state of the section
    if (this.isCollapsed) {
      this.sidebarState.collapseSection(this.args.sectionName);
    } else {
      this.sidebarState.expandSection(this.args.sectionName);
    }

    // override the expanded state if the section is active
    this.expandIfActive();
  }

  @bind
  expandIfActive(transition) {
    if (transition?.isAborted) {
      return;
    }

    this.activeExpanded = this.args.expandWhenActive && this.isActive;
  }

  get displaySectionContent() {
    if (this.args.hideSectionHeader || !isEmpty(this.sidebarState.filter)) {
      return true;
    }

    if (this.activeExpanded) {
      return true;
    }

    return !this.sidebarState.collapsedSections.has(
      this.collapsedSidebarSectionKey
    );
  }

  @action
  toggleSectionDisplay(_, event) {
    this.activeExpanded = false;

    if (this.displaySectionContent) {
      this.sidebarState.collapseSection(this.args.sectionName);
    } else {
      this.sidebarState.expandSection(this.args.sectionName);
    }

    // remove focus from the toggle, but only on click
    if (!event.key) {
      document.activeElement.blur();
    }
  }

  @action
  onRegisterApi(api) {
    this.dMenu = api;
  }

  @action
  handleHeaderActionClick(headerAction) {
    headerAction();
    this.dMenu.close();

    if (this.args.toggleNavigationMenu) {
      next(this.args.toggleNavigationMenu);
    }
  }

  get linkDropAtEnd() {
    return this.linkDropActive && this.linkDropIndex === this.linkDropLinkCount;
  }

  /**
   * Files are their own drag with their own destinations, and a section only
   * knows what to do with a URL. Gated here rather than by leaving the target
   * off, so a section that becomes droppable mid-drag does not have to register
   * one halfway through.
   */
  @action
  canDropLink({ source }) {
    return (
      Boolean(this.args.linkDropEnabled) &&
      !webLinkPayload(source).containsFiles()
    );
  }

  /**
   * Tracks where in this section's links a drop would land.
   *
   * The section is the drop target, not the rows: a link row is not somewhere a
   * drop can land in its own right, it only marks an offset within the section
   * the drop is already going to. So the position is measured here against the
   * rows rather than delegated to a target on each of them.
   */
  @action
  trackLinkDrop({ source, location, element }) {
    // A drag carrying only text may well turn out to hold nothing droppable, so
    // the insertion point stays hidden until the drag declares a real URL.
    this.linkDropActive = webLinkPayload(source).containsURLs();

    if (!this.linkDropActive) {
      this.linkDropIndex = undefined;
      return;
    }

    if (!this.displaySectionContent) {
      // Reporting a position here would be inventing one: there is nothing on
      // screen for the pointer to be above or below, and an index of 0 would
      // put the link ahead of links the user cannot see. Leaving it unset
      // appends, until dwelling opens the section and the rows can be measured.
      this.linkDropIndex = undefined;
      this.linkDropLinkCount = 0;
      return;
    }

    const links = Array.from(
      element.querySelectorAll("[data-sidebar-custom-link]")
    );
    const { clientY } = location.current.input;
    const index = links.findIndex((link) => {
      const { top, height } = link.getBoundingClientRect();
      return clientY < top + height / 2;
    });

    this.linkDropLinkCount = links.length;
    this.linkDropIndex = index === -1 ? links.length : index;
  }

  @action
  clearLinkDrop() {
    this.linkDropLinkCount = 0;
    this.linkDropActive = false;
    this.linkDropIndex = undefined;
  }

  @action
  dropLink({ source }) {
    const linkDropIndex = this.linkDropIndex;
    this.clearLinkDrop();
    // Unwrapped here so `onLinkDrop` keeps taking a decorated payload whichever
    // target reported the drop, and the section model needs no change.
    this.args.onLinkDrop?.(webLinkPayload(source), linkDropIndex);
  }

  /**
   * Arms the open-on-hover dwell: only for a drag carrying a real URL, and
   * only while this section is closed. An open section has nothing to reveal.
   */
  @action
  canDwellToOpen({ source }) {
    return (
      !this.displaySectionContent &&
      this.canDropLink({ source }) &&
      webLinkPayload(source).containsURLs()
    );
  }

  /**
   * Opens this section once a link has dwelled over it long enough, the way a
   * folder opens under a file held over it.
   *
   * Uses the transient active-expansion rather than the collapse toggle, so a
   * drag that wanders off again leaves no trace in the stored collapsed state.
   */
  @action
  openForLinkDwell() {
    this.#openedForDrag = true;
    this.activeExpanded = true;
  }

  /**
   * Closes the section again when the dwell ends without a drop landing in
   * it. A drop here keeps it open: the link the user just added is inside,
   * and closing would hide the result of their own drop.
   */
  @action
  endLinkDwell({ droppedHere }) {
    if (droppedHere) {
      this.#openedForDrag = false;
      return;
    }

    this.#collapseIfOpenedForDrag();
  }

  get headerCaretIcon() {
    return this.displaySectionContent ? "angle-down" : "angle-right";
  }

  get isSingleHeaderAction() {
    return this.args.headerActions?.length === 1;
  }

  get isMultipleHeaderActions() {
    return this.args.headerActions?.length > 1;
  }

  get displaySection() {
    if (this.args.displaySection === undefined) {
      return true;
    }

    return this.args.displaySection;
  }

  #collapseIfOpenedForDrag() {
    if (this.#openedForDrag) {
      this.#openedForDrag = false;
      this.activeExpanded = false;
    }
  }

  <template>
    {{#if this.displaySection}}
      <div
        {{didInsert this.setExpandedState}}
        {{dDragAndDropExternalTarget
          accepts=WEB_LINK_KINDS
          canDrop=this.canDropLink
          dropEffect="copy"
          indicator=false
          onDragEnter=this.trackLinkDrop
          onDrag=this.trackLinkDrop
          onDragLeave=this.clearLinkDrop
          onDrop=this.dropLink
        }}
        {{! The same drop, for a link the browser started dragging from this
            page rather than from outside the window. }}
        {{dDragAndDropTarget
          adopts=WEB_LINK_ADOPTION
          canDrop=this.canDropLink
          dropEffect="copy"
          indicator=false
          onDragEnter=this.trackLinkDrop
          onDrag=this.trackLinkDrop
          onDragLeave=this.clearLinkDrop
          onDrop=this.dropLink
        }}
        {{dDragDwell
          types=WEB_LINK_ADOPTION.type
          externalKinds=WEB_LINK_KINDS
          canDwell=this.canDwellToOpen
          onDwell=this.openForLinkDwell
          onDwellEnd=this.endLinkDwell
        }}
        data-section-name={{@sectionName}}
        class={{dConcatClass
          "sidebar-section"
          "sidebar-section-wrapper"
          (if this.linkDropActive "is-link-drop-active")
          (if
            this.displaySectionContent
            "sidebar-section--expanded"
            "sidebar-section--collapsed"
          )
        }}
        ...attributes
      >
        {{#unless @hideSectionHeader}}
          <div class="sidebar-section-header-wrapper sidebar-row">
            <SectionHeader
              @collapsable={{@collapsable}}
              @sidebarSectionContentId={{this.sidebarSectionContentId}}
              @toggleSectionDisplay={{this.toggleSectionDisplay}}
              @isExpanded={{this.displaySectionContent}}
              @isActive={{this.isActive}}
            >
              {{#if @collapsable}}
                <span class="sidebar-section-header-caret">
                  {{dIcon this.headerCaretIcon}}
                </span>
              {{/if}}

              <span class="sidebar-section-header-text">
                {{@headerLinkText}}
              </span>

              {{#if @indicatePublic}}
                <DTooltip
                  @icon="globe"
                  class="sidebar-section-header-global-indicator"
                >
                  <span
                    class="sidebar-section-header-global-indicator__content"
                  >
                    {{dIcon "shield-halved"}}
                    {{i18n "sidebar.sections.global_section"}}
                  </span>
                </DTooltip>
              {{/if}}
            </SectionHeader>

            {{#if this.isSingleHeaderAction}}
              {{#each @headerActions as |headerAction|}}
                <button
                  {{on "click" headerAction.action}}
                  type="button"
                  title={{headerAction.title}}
                  class="sidebar-section-header-button btn-icon btn-flat"
                >
                  {{dIcon @headerActionsIcon}}
                </button>
              {{/each}}
            {{/if}}

            {{#if this.isMultipleHeaderActions}}
              <DMenu
                @identifier="sidebar-section-header-dropdown-menu"
                @title={{i18n "sidebar.sections.more_options.title"}}
                @icon="ellipsis-vertical"
                @onRegisterApi={{this.onRegisterApi}}
                class="sidebar-section-header-dropdown btn-flat"
              >
                <:content>
                  <DDropdownMenu as |dropdown|>
                    {{#each @headerActions as |headerAction|}}
                      <dropdown.item>
                        <DButton
                          @action={{fn
                            this.handleHeaderActionClick
                            headerAction.action
                          }}
                          @translatedLabel={{headerAction.title}}
                          class="btn-transparent sidebar-section-header-dropdown__item"
                          data-menu-option-id={{headerAction.id}}
                        />
                      </dropdown.item>
                    {{/each}}
                  </DDropdownMenu>
                </:content>
              </DMenu>
            {{/if}}
          </div>
        {{/unless}}

        {{#if this.displaySectionContent}}
          <ul
            id={{this.sidebarSectionContentId}}
            class="sidebar-section-content"
          >
            {{yield (hash linkDropIndex=this.linkDropIndex)}}
          </ul>
        {{/if}}

        {{#if this.linkDropAtEnd}}
          <div
            class="sidebar-section-link-drop-indicator"
            aria-hidden="true"
          ></div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
