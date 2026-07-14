// @ts-check
import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { service } from "@ember/service";
import { modifier } from "ember-modifier";
import { isTesting } from "discourse/lib/environment";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";
/** @type {import("./activity-entry-tooltip.gjs").default} */
import ActivityEntryTooltip from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/activity-entry-tooltip";

/**
 * The editor's left activity bar: a persistent vertical strip of icon-only
 * toggle buttons that pick which wide panel the left rail shows (Add, Layers,
 * and the Issues slot whose body lands in a later phase). It stays visible even
 * when the wide panel is collapsed — the strip IS the collapsed state.
 *
 * The entries carry no visible text (the 48px rail is too narrow for legible
 * labels); each is named for assistive tech via `aria-label` and, for sighted
 * users, by a hover card showing the name plus a one-line hint.
 *
 * Modeled as a toolbar of toggle buttons (not a tablist): clicking the open
 * panel's entry collapses it, so `aria-pressed` cleanly tracks "this panel is
 * open" without an ARIA tab pointing at a hidden panel. Future panels are
 * reserved by extending `ENTRIES`, not by rendering disabled placeholders.
 */
export default class ActivityBar extends Component {
  static ENTRIES = [
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

  @service tooltip;
  @service wireframeRail;
  @service wireframeValidation;

  /**
   * Registers the entry's hover card (name + hint). Hover-only — focus moves
   * between entries on Tab, so a focus trigger would flash the card on every
   * step; the `aria-label` already names the button for keyboard / SR users.
   * Suppressed in tests, where FloatKit timing would make assertions flaky and
   * the card adds no coverage. Mirrors the palette tile's preview registration.
   */
  registerTooltip = modifier((element, [entry]) => {
    if (isTesting()) {
      return;
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
  });

  /**
   * How many validation issues the page currently has. Drives the count
   * badge on the Issues entry — equal to the number of rows the Issues
   * panel renders, so the badge and the panel always agree.
   *
   * @returns {number}
   */
  get issueCount() {
    return this.wireframeValidation.validationIssues.length;
  }

  /**
   * The rail entries, each decorated with the count that its badge (if
   * any) should show. Only the Issues entry carries a live count today;
   * the rest stay at zero so the template renders no badge for them. When
   * issues exist, the Issues entry also gets a count-aware aria-label so
   * assistive tech announces the number without the (aria-hidden) badge.
   *
   * @returns {Array<Object>}
   */
  get entries() {
    return ActivityBar.ENTRIES.map((entry) => {
      if (entry.tab === "issues" && this.issueCount > 0) {
        return {
          ...entry,
          badgeCount: this.issueCount,
          translatedAriaLabel: i18n("wireframe.chrome.panel_issues_count", {
            count: this.issueCount,
          }),
        };
      }
      return { ...entry, badgeCount: 0, translatedAriaLabel: null };
    });
  }

  <template>
    <div
      class="wireframe-activity-bar"
      role="toolbar"
      aria-orientation="vertical"
      aria-label={{i18n "wireframe.chrome.activity_bar_label"}}
      {{! One vertical rove over the panel entries and the bottom collapse
        chevron: the whole strip is a single tab stop, Up/Down move between its
        buttons, Enter/Space activate. }}
      {{dRovingFocus
        orientation="vertical"
        itemSelector=".wireframe-activity-bar__entry, .wireframe-activity-bar__collapse"
      }}
    >
      {{#each this.entries key="tab" as |entry|}}
        {{! Wraps the button so the count badge can position against it.
            The badge is aria-hidden — the entry's aria-label carries the
            count for assistive tech. }}
        <span class="wireframe-activity-bar__entry-wrap">
          <DButton
            class={{dConcatClass
              "btn-flat wireframe-activity-bar__entry"
              (if (this.wireframeRail.isPanelOpen entry.tab) "--active")
            }}
            @icon={{entry.icon}}
            @ariaLabel={{unless entry.translatedAriaLabel entry.label}}
            @translatedAriaLabel={{entry.translatedAriaLabel}}
            @ariaPressed={{this.wireframeRail.isPanelOpen entry.tab}}
            @action={{fn this.wireframeRail.activatePanel entry.tab}}
            {{this.registerTooltip entry}}
          />
          {{#if entry.badgeCount}}
            <span class="wireframe-activity-bar__badge" aria-hidden="true">
              {{entry.badgeCount}}
            </span>
          {{/if}}
        </span>
      {{/each}}

      {{! Persistent two-way collapse toggle, pinned to the bottom of the rail.
          Mirrors the right panel's chevron; lives in the always-visible rail so
          it survives collapse and keeps focus inside the rail. }}
      <DButton
        class="btn-flat wireframe-activity-bar__collapse"
        @icon={{if
          this.wireframeRail.leftCollapsed
          "chevron-right"
          "chevron-left"
        }}
        @ariaExpanded={{if this.wireframeRail.leftCollapsed false true}}
        @title={{if
          this.wireframeRail.leftCollapsed
          "wireframe.chrome.expand_panel"
          "wireframe.chrome.collapse_panel"
        }}
        @ariaLabel={{if
          this.wireframeRail.leftCollapsed
          "wireframe.chrome.expand_panel"
          "wireframe.chrome.collapse_panel"
        }}
        @action={{this.wireframeRail.toggleLeftCollapsed}}
      />
    </div>
  </template>
}
