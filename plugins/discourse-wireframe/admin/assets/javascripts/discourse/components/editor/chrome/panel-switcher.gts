import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { type ComponentLike } from "@glint/template";
import DSegmentedControlUntyped from "discourse/components/d-segmented-control";
import { gt } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";
import WireframeRailService, {
  type WireframeRailPanel,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-rail";
import type WireframeValidationService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-validation";

/** One section of the left panel: the rail panel it shows and its name. */
type Section = {
  /** Rail panel shown by the section. */
  tab: WireframeRailPanel;
  /** Translation key naming the section. */
  label: string;
};

/** One choice offered by the segmented control. */
type Segment = {
  /** Rail panel the segment selects. */
  value: WireframeRailPanel;
  /** Visible segment text. */
  label: string;
  /** Accessible name, when it should say more than the visible text. */
  title?: string;
};

// TODO(typescript-pending): drop once DSegmentedControl is authored in .gts
// with a real Signature, then import it directly.
const DSegmentedControl = DSegmentedControlUntyped as unknown as ComponentLike<{
  Element: HTMLFieldSetElement;
  Args: {
    items: Segment[];
    name: string;
    onSelect: (value: string) => void;
    translatedLabel?: string;
    value: string;
  };
}>;

interface EditorPanelSwitcherSignature {
  Element: HTMLDivElement;
  Blocks: {
    /** Content of the active section. */
    default: [
      /** The panel whose content the shell should render. */
      panel: WireframeRailPanel,
    ];
  };
}

/**
 * The editor's left panel: a segmented control naming its sections (Blocks,
 * Layers, Issues) above the active section's content. With a single visible
 * section the header names it instead. The selection lives on the rail
 * service, so detached UI can switch sections too.
 */
export default class EditorPanelSwitcher extends Component<EditorPanelSwitcherSignature> {
  /** The sections, in display order. */
  static SECTIONS: Section[] = [
    { tab: "palette", label: "wireframe.chrome.panel_blocks" },
    { tab: "outline", label: "wireframe.chrome.panel_layers" },
    { tab: "issues", label: "wireframe.chrome.panel_issues" },
  ];

  /** Sections kept out of the panel for now; only the blocks are offered. */
  static HIDDEN_SECTIONS: WireframeRailPanel[] = ["outline", "issues"];

  /** Owns the active section. */
  @service declare wireframeRail: WireframeRailService;

  /** Supplies the live issue count. */
  @service declare wireframeValidation: WireframeValidationService;

  /** The sections the panel offers, in display order. */
  get sections(): Section[] {
    return EditorPanelSwitcher.SECTIONS.filter(
      ({ tab }) => !EditorPanelSwitcher.HIDDEN_SECTIONS.includes(tab)
    );
  }

  /**
   * The section to show. A stored choice of a hidden section falls back to the
   * first visible one.
   */
  get activeSection(): Section {
    return (
      this.sections.find(
        ({ tab }) => tab === this.wireframeRail.leftPanelTab
      ) ?? this.sections[0]
    );
  }

  /**
   * How many validation issues the page currently has. Equal to the number of
   * rows the Issues section renders, so the count and the section agree.
   */
  get issueCount(): number {
    return this.wireframeValidation.validationIssues.length;
  }

  /**
   * The segments, with the Issues one carrying the live count in its visible
   * text and a count-aware accessible name.
   */
  get segments(): Segment[] {
    return this.sections.map(({ tab, label }) => {
      if (tab === "issues" && this.issueCount > 0) {
        return {
          value: tab,
          label: i18n("wireframe.chrome.panel_issues_with_count", {
            count: this.issueCount,
          }),
          title: i18n("wireframe.chrome.panel_issues_count", {
            count: this.issueCount,
          }),
        };
      }
      return { value: tab, label: i18n(label) };
    });
  }

  @action
  selectSection(value: string): void {
    const section = this.sections.find((candidate) => candidate.tab === value);
    if (section) {
      this.wireframeRail.setLeftPanelTab(section.tab);
    }
  }

  <template>
    <div class="wireframe-panel-switcher wireframe-panel --left" ...attributes>
      <div class="panel-header">
        {{#if (gt this.sections.length 1)}}
          <DSegmentedControl
            class="wireframe-panel-switcher__sections --full-width"
            @items={{this.segments}}
            @name="wireframe-panel-switcher"
            @onSelect={{this.selectSection}}
            @translatedLabel={{i18n "wireframe.chrome.panel_switcher_label"}}
            @value={{this.activeSection.tab}}
          />
        {{else}}
          <span class="wireframe-panel-switcher__title">
            {{i18n this.activeSection.label}}
          </span>
        {{/if}}
      </div>
      <div class="panel-body">{{yield this.activeSection.tab}}</div>
    </div>
  </template>
}
