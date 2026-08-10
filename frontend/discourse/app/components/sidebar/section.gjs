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
import { WEB_LINK_KINDS } from "discourse/lib/sidebar/link-drop";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropExternalTarget from "discourse/ui-kit/modifiers/d-drag-and-drop-external-target";
import { i18n } from "discourse-i18n";
import SectionHeader from "./section-header";

/** Dropping a link here copies it into the section; it does not move anything. */
const copyDropEffect = () => "copy";

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

  constructor() {
    super(...arguments);

    this.router.on("routeDidChange", this, this.expandIfActive);
  }

  willDestroy() {
    super.willDestroy(...arguments);

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
    return Boolean(this.args.linkDropEnabled) && !source.containsFiles();
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
    this.linkDropActive = source.containsURLs();

    if (!this.linkDropActive) {
      this.linkDropIndex = undefined;
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
    this.args.onLinkDrop?.(source, linkDropIndex);
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

  <template>
    {{#if this.displaySection}}
      <div
        {{didInsert this.setExpandedState}}
        {{dDragAndDropExternalTarget
          accepts=WEB_LINK_KINDS
          canDrop=this.canDropLink
          getDropEffect=copyDropEffect
          indicator=false
          onDragEnter=this.trackLinkDrop
          onDrag=this.trackLinkDrop
          onDragLeave=this.clearLinkDrop
          onDrop=this.dropLink
        }}
        data-section-name={{@sectionName}}
        class={{dConcatClass
          "sidebar-section"
          "sidebar-section-wrapper"
          (if @linkDropEnabled "is-link-drop-enabled")
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
