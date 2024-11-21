import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import concatClass from "discourse/helpers/concat-class";
import {
  getCollapsedSidebarSectionKey,
  getSidebarSectionContentId,
} from "discourse/lib/sidebar/helpers";
import icon from "discourse-common/helpers/d-icon";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";
import DropdownSelectBox from "select-kit/components/dropdown-select-box";
import DTooltip from "float-kit/components/d-tooltip";
import SectionHeader from "./section-header";

export default class SidebarSection extends Component {
  @service keyValueStore;
  @service router;
  @service sidebarState;

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
  handleMultipleHeaderActions(id) {
    this.args.headerActions
      .find((headerAction) => headerAction.id === id)
      .action();
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
        data-section-name={{@sectionName}}
        class={{concatClass
          "sidebar-section"
          "sidebar-section-wrapper"
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
                  {{icon this.headerCaretIcon}}
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
                    {{icon "shield-halved"}}
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
                  class="sidebar-section-header-button"
                >
                  {{icon @headerActionsIcon}}
                </button>
              {{/each}}
            {{/if}}

            {{#if this.isMultipleHeaderActions}}
              <DropdownSelectBox
                @options={{hash
                  icon=@headerActionsIcon
                  placementStrategy="absolute"
                }}
                @content={{@headerActions}}
                @onChange={{this.handleMultipleHeaderActions}}
                class="sidebar-section-header-dropdown"
              />
            {{/if}}
          </div>
        {{/unless}}

        {{#if this.displaySectionContent}}
          <ul
            id={{this.sidebarSectionContentId}}
            class="sidebar-section-content"
          >
            {{yield}}
          </ul>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
