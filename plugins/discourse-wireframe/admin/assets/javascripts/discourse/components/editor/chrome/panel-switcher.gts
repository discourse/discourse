import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import type TooltipService from "discourse/float-kit/services/tooltip";
import { isTesting } from "discourse/lib/environment";
import DButton from "discourse/ui-kit/d-button";
import DTabs from "discourse/ui-kit/d-tabs";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ActivityEntryTooltip from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/activity-entry-tooltip";
import WireframeRailService, {
  type WireframeRailPanel,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-rail";
import type WireframeValidationService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-validation";

/**
 * A static rail entry: its target panel plus the icon and i18n keys the button
 * and hover card render from.
 */
type PanelEntry = {
  /** Rail panel opened by the entry. */
  tab: WireframeRailPanel;
  /** Icon ID rendered by the entry. */
  icon: string;
  /** Translation key naming the entry. */
  label: string;
  /** Translation key describing the entry. */
  description: string;
};

/**
 * A rail entry decorated with its live badge count and (when non-zero) a
 * count-aware translated aria-label.
 */
type DecoratedPanelEntry = PanelEntry & {
  /** Validation badge count shown by the entry. */
  badgeCount: number;
  /** Count-aware accessible label, or `undefined` without a badge. */
  translatedAriaLabel: string | undefined;
};

interface EditorPanelSwitcherSignature {
  Element: HTMLDivElement;
  Blocks: {
    /** Content of the expanded panel; unmounted when collapsed or inactive. */
    default: [
      /** The panel whose content the shell should render. */
      panel: WireframeRailPanel,
    ];
  };
}

export default class EditorPanelSwitcher extends Component<EditorPanelSwitcherSignature> {
  /** Static activity entries rendered in rail order. */
  static ENTRIES: PanelEntry[] = [
    {
      tab: "palette",
      icon: "plus",
      label: "wireframe.chrome.panel_add",
      description: "wireframe.chrome.panel_add_description",
    },
    {
      tab: "outline",
      icon: "layer-group",
      label: "wireframe.chrome.panel_layers",
      description: "wireframe.chrome.panel_layers_description",
    },
    {
      tab: "issues",
      icon: "triangle-exclamation",
      label: "wireframe.chrome.panel_issues",
      description: "wireframe.chrome.panel_issues_description",
    },
  ];

  /** Registers activity-entry hover cards. */
  @service declare tooltip: TooltipService;

  /** Owns the active and collapsed rail-panel state. */
  @service declare wireframeRail: WireframeRailService;

  /** Supplies the live issue count. */
  @service declare wireframeValidation: WireframeValidationService;

  /**
   * Hover-only so arrow-key navigation does not open tooltips on every step.
   */
  registerTooltip = modifier(
    (element: HTMLElement, [entry]: [DecoratedPanelEntry]) => {
      if (isTesting()) {
        return undefined;
      }
      const instance = this.tooltip.register(element, {
        component: ActivityEntryTooltip,
        data: { entry },
        interactive: false,
        triggers: ["hover"],
        placement: "right",
        fallbackPlacements: ["top", "bottom"],
        animated: false,
      });
      return () => instance.destroy();
    }
  );

  get activePanel(): WireframeRailPanel | undefined {
    return this.wireframeRail.leftCollapsed
      ? undefined
      : this.wireframeRail.leftPanelTab;
  }

  /**
   * How many validation issues the page currently has. Drives the count
   * badge on the Issues entry — equal to the number of rows the Issues
   * panel renders, so the badge and the panel always agree.
   */
  get issueCount(): number {
    return this.wireframeValidation.validationIssues.length;
  }

  /**
   * The rail entries, each decorated with the count that its badge (if
   * any) should show. Only the Issues entry carries a live count today;
   * the rest stay at zero so the template renders no badge for them. When
   * issues exist, the Issues entry also gets a count-aware aria-label so
   * assistive tech announces the number without the (aria-hidden) badge.
   */
  get entries(): DecoratedPanelEntry[] {
    return EditorPanelSwitcher.ENTRIES.map((entry) => {
      if (entry.tab === "issues" && this.issueCount > 0) {
        return {
          ...entry,
          badgeCount: this.issueCount,
          translatedAriaLabel: i18n("wireframe.chrome.panel_issues_count", {
            count: this.issueCount,
          }),
        };
      }
      return { ...entry, badgeCount: 0, translatedAriaLabel: undefined };
    });
  }

  @action
  activatePanel(key: string): void {
    const entry = EditorPanelSwitcher.ENTRIES.find(
      (candidate) => candidate.tab === key
    );
    if (entry) {
      this.wireframeRail.activatePanel(entry.tab);
    }
  }

  <template>
    <DTabs
      class={{dConcatClass
        "wireframe-panel-switcher"
        (if this.wireframeRail.leftCollapsed "--collapsed")
      }}
      ...attributes
      @active={{this.activePanel}}
      @label={{i18n "wireframe.chrome.activity_bar_label"}}
      @onActivate={{this.activatePanel}}
      @orientation="vertical"
    >
      <:header as |header|>
        <div class="wireframe-panel-switcher__activity-bar">
          <header.Tablist />
          <DButton
            class="btn-flat wireframe-panel-switcher__collapse"
            @action={{this.wireframeRail.toggleLeftCollapsed}}
            @ariaExpanded={{if this.wireframeRail.leftCollapsed false true}}
            @ariaLabel={{if
              this.wireframeRail.leftCollapsed
              "wireframe.chrome.expand_panel"
              "wireframe.chrome.collapse_panel"
            }}
            @icon={{if
              this.wireframeRail.leftCollapsed
              "chevron-right"
              "chevron-left"
            }}
            @title={{if
              this.wireframeRail.leftCollapsed
              "wireframe.chrome.expand_panel"
              "wireframe.chrome.collapse_panel"
            }}
          />
        </div>
      </:header>
      <:default as |tabs|>
        {{#each this.entries key="tab" as |entry|}}
          <tabs.Tab
            aria-label={{if
              entry.translatedAriaLabel
              entry.translatedAriaLabel
              (i18n entry.label)
            }}
            class="wireframe-panel-switcher__entry"
            @key={{entry.tab}}
            {{this.registerTooltip entry}}
          >
            <:label>
              {{dIcon entry.icon}}
              {{#if entry.badgeCount}}
                <span
                  aria-hidden="true"
                  class="wireframe-panel-switcher__badge"
                >{{entry.badgeCount}}</span>
              {{/if}}
            </:label>
            <:default>
              <div class="wireframe-panel --left">
                <div class="panel-header"><span>{{i18n
                      entry.label
                    }}</span></div>
                <div class="panel-body">{{yield entry.tab}}</div>
              </div>
            </:default>
          </tabs.Tab>
        {{/each}}
      </:default>
    </DTabs>
  </template>
}
