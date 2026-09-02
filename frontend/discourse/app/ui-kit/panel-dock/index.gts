import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat } from "@ember/helper";
import { action } from "@ember/object";
import type { ComponentLike } from "@glint/template";
import DButton from "discourse/ui-kit/d-button";
import DTabs from "discourse/ui-kit/d-tabs";
import PanelDockChassis from "discourse/ui-kit/panel-dock/-internals/panel";
import type { DockSide } from "discourse/ui-kit/panel-dock/-internals/sides";
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

/**
 * A context-identified, tabbed panel docked to a viewport edge.
 *
 * Tab selection is internal unless `@activeTab` is supplied, which is the one
 * thing this adds over `DTabs` alone: the dock always has something open, so
 * it falls back to the first tab rather than showing an empty panel.
 *
 * A lone tab is shown without a strip. Tabs that are not a choice are not a
 * tabs widget, so that case is a plain panel body rather than a one-item
 * tablist announcing a selection nobody can change.
 */
export default class DPanelDock extends Component<DPanelDockSignature> {
  /**
   * Deliberately not seeded from args: reading them during construction
   * consumes upstream tracked state, and the getter already falls back to
   * the first tab while this holds no live id.
   */
  @tracked _activeTab: string | undefined;

  get activeTabId() {
    if (this.args.activeTab !== undefined) {
      return this.args.activeTab;
    }

    return this.args.tabs.some((tab) => tab.id === this._activeTab)
      ? this._activeTab
      : this.args.tabs[0]?.id;
  }

  get activeTab() {
    return this.args.tabs.find((tab) => tab.id === this.activeTabId);
  }

  get activeComponent() {
    return this.activeTab?.component;
  }

  get hasMultipleTabs() {
    return this.args.tabs.length > 1;
  }

  @action
  activateTab(id: string) {
    if (this.args.activeTab === undefined) {
      this._activeTab = id;
    }

    this.args.onActivateTab?.(id);
  }

  <template>
    {{#if this.hasMultipleTabs}}
      <PanelDockChassis
        class={{concat "--context-" @context}}
        ...attributes
        @isOpen={{@isOpen}}
        @storageKey={{@context}}
        @dockable={{@dockable}}
        @defaultSide={{@defaultSide}}
        @defaultWidth={{@defaultWidth}}
      >
        {{! The tab strip and the panel it drives are one widget, so they
            take the whole interior and rebuild the header row around the
            tablist rather than being split across the chassis blocks. }}
        <:main as |controls|>
          <DTabs
            class="d-panel-dock__tabs-host"
            @active={{this.activeTabId}}
            @onActivate={{this.activateTab}}
            @label={{i18n "panel_dock.tabs"}}
          >
            <:header as |header|>
              <div class="d-panel-dock__header">
                <header.Tablist />

                <div class="d-panel-dock__actions">
                  {{#if @dockable}}
                    <controls.DockPicker />
                  {{/if}}

                  {{#if @onClose}}
                    <DButton
                      class="btn-transparent d-panel-dock__close"
                      @icon="xmark"
                      @action={{@onClose}}
                      @title="panel_dock.close"
                      @ariaLabel="panel_dock.close"
                    />
                  {{/if}}
                </div>
              </div>
            </:header>

            <:default as |tabs|>
              {{#each @tabs key="id" as |tab|}}
                <tabs.Tab
                  class="d-panel-dock__tab"
                  @id={{tab.id}}
                  @label={{tab.label}}
                >
                  {{component tab.component}}
                </tabs.Tab>
              {{/each}}
            </:default>
          </DTabs>
        </:main>
      </PanelDockChassis>
    {{else}}
      <PanelDockChassis
        class={{concat "--context-" @context}}
        ...attributes
        @isOpen={{@isOpen}}
        @storageKey={{@context}}
        @dockable={{@dockable}}
        @defaultSide={{@defaultSide}}
        @defaultWidth={{@defaultWidth}}
      >
        <:actions>
          {{#if @onClose}}
            <DButton
              class="btn-transparent d-panel-dock__close"
              @icon="xmark"
              @action={{@onClose}}
              @title="panel_dock.close"
              @ariaLabel="panel_dock.close"
            />
          {{/if}}
        </:actions>

        <:body>
          {{#if this.activeComponent}}
            {{component this.activeComponent}}
          {{/if}}
        </:body>
      </PanelDockChassis>
    {{/if}}
  </template>
}
