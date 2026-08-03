import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type { ComponentLike } from "@glint/template";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import PanelDockChassis, {
  type DockSide,
} from "discourse/ui-kit/panel-dock/-internals/panel";
import { i18n } from "discourse-i18n";

/** A tab displayed by {@link DPanelDock}. */
export interface DPanelDockTab {
  /** The stable identity used for selection and accessible element IDs. */
  id: string;

  /** The text displayed in the tab strip. */
  label: string;

  /** The component rendered while this tab is active. */
  component: ComponentLike;
}

interface DPanelDockSignature {
  /** The docked panel element. */
  Element: HTMLDivElement;
  Args: {
    /** The identity used for styling and persisted layout storage. */
    context: string;

    /** Whether the panel is rendered. */
    isOpen?: boolean;

    /** Called when the close button is pressed. */
    onClose?: () => void;

    /** Tabs available in the panel, in display order. */
    tabs: DPanelDockTab[];

    /** The active tab ID when selection is controlled by the caller. */
    activeTab?: string;

    /** Called with the ID of a tab the user activates. */
    onActivateTab?: (id: string) => void;

    /** Whether the panel offers controls for changing its docked side. */
    dockable?: boolean;

    /** The side used until a persisted layout or user choice overrides it. */
    defaultSide?: DockSide;

    /** The initial panel width in pixels. */
    defaultWidth?: number;
  };
}

type RenderedTab = DPanelDockTab & {
  index: number;
  panelId: string;
  tabId: string;
};

/**
 * A context-identified, tabbed panel docked to a viewport edge.
 *
 * Tab selection is internal unless `@activeTab` is supplied. Keyboard focus
 * follows the manual-activation tabs pattern, so arrow keys move focus and
 * Enter or Space activates the focused tab.
 */
export default class DPanelDock extends Component<DPanelDockSignature> {
  // Deliberately not seeded from args: reading them during construction
  // consumes upstream tracked state, and the getter already falls back to
  // the first tab while this holds no live id.
  @tracked _activeTab: string | undefined;
  @tracked _focusedTabIndex = 0;

  get tabs(): RenderedTab[] {
    return this.args.tabs.map((tab, index) => ({
      ...tab,
      index,
      panelId: `d-panel-dock-${this.args.context}-panel-${tab.id}`,
      tabId: `d-panel-dock-${this.args.context}-tab-${tab.id}`,
    }));
  }

  get activeTabId() {
    if (this.args.activeTab !== undefined) {
      return this.args.activeTab;
    }

    return this.tabs.some((tab) => tab.id === this._activeTab)
      ? this._activeTab
      : this.tabs[0]?.id;
  }

  get activeTab() {
    return this.tabs.find((tab) => tab.id === this.activeTabId);
  }

  get activeComponent() {
    return this.activeTab?.component;
  }

  get activePanelId() {
    return this.activeTab?.panelId;
  }

  get activeTabElementId() {
    return this.activeTab?.tabId;
  }

  get focusedTabIndex() {
    return Math.min(this._focusedTabIndex, Math.max(this.tabs.length - 1, 0));
  }

  get hasMultipleTabs() {
    return this.tabs.length > 1;
  }

  @action
  activateTab(id: string, index: number) {
    this._focusedTabIndex = index;

    if (this.args.activeTab === undefined) {
      this._activeTab = id;
    }

    this.args.onActivateTab?.(id);
  }

  @action
  focusTab(index: number) {
    this._focusedTabIndex = index;
  }

  @action
  handleTabKeydown(id: string, index: number, event: KeyboardEvent) {
    let targetIndex: number | undefined;

    switch (event.key) {
      case "ArrowLeft":
        targetIndex = (index - 1 + this.tabs.length) % this.tabs.length;
        break;
      case "ArrowRight":
        targetIndex = (index + 1) % this.tabs.length;
        break;
      case "Home":
        targetIndex = 0;
        break;
      case "End":
        targetIndex = this.tabs.length - 1;
        break;
      case "Enter":
      case " ":
        event.preventDefault();
        this.activateTab(id, index);
        return;
      default:
        return;
    }

    event.preventDefault();
    this._focusedTabIndex = targetIndex;

    const tablist = (event.currentTarget as HTMLElement).parentElement;
    tablist
      ?.querySelectorAll<HTMLButtonElement>("[role='tab']")
      [targetIndex]?.focus();
  }

  <template>
    <PanelDockChassis
      @isOpen={{@isOpen}}
      @storageKey={{@context}}
      @dockable={{@dockable}}
      @defaultSide={{@defaultSide}}
      @defaultWidth={{@defaultWidth}}
      class={{concat "--context-" @context}}
      ...attributes
    >
      <:header>
        {{#if this.hasMultipleTabs}}
          <div
            class="d-panel-dock__tabs"
            role="tablist"
            aria-label={{i18n "panel_dock.tabs"}}
          >
            {{#each this.tabs as |tab|}}
              <button
                id={{tab.tabId}}
                type="button"
                class="d-panel-dock__tab"
                role="tab"
                aria-controls={{tab.panelId}}
                aria-selected={{if (eq tab.id this.activeTabId) "true" "false"}}
                tabindex={{if (eq tab.index this.focusedTabIndex) "0" "-1"}}
                {{on "focus" (fn this.focusTab tab.index)}}
                {{on "keydown" (fn this.handleTabKeydown tab.id tab.index)}}
                {{on "click" (fn this.activateTab tab.id tab.index)}}
              >
                {{tab.label}}
              </button>
            {{/each}}
          </div>
        {{/if}}
      </:header>

      <:actions>
        {{#if @onClose}}
          <DButton
            @icon="xmark"
            @action={{@onClose}}
            @title="panel_dock.close"
            @ariaLabel="panel_dock.close"
            class="btn-transparent d-panel-dock__close"
          />
        {{/if}}
      </:actions>

      <:body>
        {{#if this.activeComponent}}
          {{#if this.hasMultipleTabs}}
            <div
              id={{this.activePanelId}}
              class="d-panel-dock__tabpanel"
              role="tabpanel"
              aria-labelledby={{this.activeTabElementId}}
            >
              {{component this.activeComponent}}
            </div>
          {{else}}
            {{component this.activeComponent}}
          {{/if}}
        {{/if}}
      </:body>
    </PanelDockChassis>
  </template>
}
