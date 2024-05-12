import Component from "@glimmer/component";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import icon from "discourse-common/helpers/d-icon";
import i18n from "discourse-common/helpers/i18n";
import { bind } from "discourse-common/utils/decorators";
import DropdownSelectBox from "select-kit/components/dropdown-select-box";
import DTooltip from "float-kit/components/d-tooltip";
import SectionHeader from "./section-header";

export default class SidebarSection extends Component {
  @service keyValueStore;
  @service sidebarState;

  sidebarSectionContentID = `sidebar-section-content-${this.args.sectionName}`;
  collapsedSidebarSectionKey = `sidebar-section-${this.args.sectionName}-collapsed`;

  willDestroy() {
    super.willDestroy(...arguments);
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

  @bind
  setExpandedState() {
    if (this.isCollapsed) {
      this.sidebarState.collapseSection(this.args.sectionName);
    } else {
      this.sidebarState.expandSection(this.args.sectionName);
    }
  }

  get displaySectionContent() {
    return !this.sidebarState.collapsedSections.has(
      this.collapsedSidebarSectionKey
    );
  }

  @action
  toggleSectionDisplay() {
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
        class="sidebar-section-wrapper sidebar-section"
        ...attributes
      >
        {{#unless @hideSectionHeader}}
          <div class="sidebar-section-header-wrapper sidebar-row">
            <SectionHeader
              @collapsable={{@collapsable}}
              @sidebarSectionContentID={{this.sidebarSectionContentID}}
              @toggleSectionDisplay={{this.toggleSectionDisplay}}
              @isExpanded={{this.displaySectionContent}}
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
                    {{icon "shield-alt"}}
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
            id={{this.sidebarSectionContentID}}
            class="sidebar-section-content"
          >
            {{yield}}
          </ul>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
