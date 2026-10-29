import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { type ComponentLike } from "@glint/template";
import DSegmentedControlUntyped from "discourse/components/d-segmented-control";
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
 * The editor's left panel: a segmented control naming its sections (Add,
 * Layers, Issues) above the active section's content. The selection lives on
 * the rail service, so detached UI can switch sections too.
 */
export default class EditorPanelSwitcher extends Component<EditorPanelSwitcherSignature> {
  /** The sections, in display order. */
  static SECTIONS: Section[] = [
    { tab: "palette", label: "wireframe.chrome.panel_add" },
    { tab: "outline", label: "wireframe.chrome.panel_layers" },
    { tab: "issues", label: "wireframe.chrome.panel_issues" },
  ];

  /** Owns the active section. */
  @service declare wireframeRail: WireframeRailService;

  /** Supplies the live issue count. */
  @service declare wireframeValidation: WireframeValidationService;

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
    return EditorPanelSwitcher.SECTIONS.map(({ tab, label }) => {
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
    const section = EditorPanelSwitcher.SECTIONS.find(
      (candidate) => candidate.tab === value
    );
    if (section) {
      this.wireframeRail.setLeftPanelTab(section.tab);
    }
  }

  <template>
    <div class="wireframe-panel-switcher wireframe-panel --left" ...attributes>
      <div class="panel-header">
        <DSegmentedControl
          class="wireframe-panel-switcher__sections --full-width"
          @items={{this.segments}}
          @name="wireframe-panel-switcher"
          @onSelect={{this.selectSection}}
          @translatedLabel={{i18n "wireframe.chrome.panel_switcher_label"}}
          @value={{this.wireframeRail.leftPanelTab}}
        />
      </div>
      <div class="panel-body">{{yield this.wireframeRail.leftPanelTab}}</div>
    </div>
  </template>
}
