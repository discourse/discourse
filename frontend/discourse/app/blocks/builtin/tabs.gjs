// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { block } from "discourse/blocks";
import { debugHooks } from "discourse/lib/blocks/-internals/debug-hooks";
import RichTextRenderer from "discourse/lib/blocks/-internals/rich-text-renderer";
import { eq } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

const VALID_ALIGNS = ["start", "center", "end"];

/**
 * A tabbed container: a horizontal strip of labels over a stack of panels,
 * showing one panel at a time. Each panel is an arbitrary child block (a
 * section / card / group for a multi-block panel), matching the rest of the
 * collapsing-container family.
 *
 * Each panel's tab label lives in the child's `containerArgs.tab.label` — the
 * parent-readable per-child metadata channel — because a container never
 * receives its children's own args. The `tabs` block reads it to build the
 * strip, falling back to "Tab N" when a child has no label yet.
 *
 * In an editing context the ambient "edit presentation" capability is set, so
 * the block reveals ALL panels stacked (each child directly selectable and
 * editable in place) while keeping the strip visible so labels stay editable
 * on it — the same expand-all approach the sibling collapsing containers use.
 */
@block("tabs", {
  container: true,
  displayName: "Tabs",
  icon: "table-columns",
  category: "Layout",
  description: "A tabbed container — one panel of blocks shown at a time.",
  args: {
    align: {
      type: "string",
      default: "start",
      enum: VALID_ALIGNS,
      ui: {
        control: "radio-group",
        label: i18n("blocks.builtin.tabs.align"),
        optionIcons: {
          start: "align-left",
          center: "align-center",
          end: "align-right",
        },
      },
    },
  },
  // Each child carries its tab label under `containerArgs.tab` — the parent
  // reads `child.containerArgs.tab.label` to build the strip. Declaring the
  // schema also surfaces the label as a per-child field in edit tooling.
  childArgs: {
    tab: {
      type: "object",
      default: { label: "" },
      properties: {
        label: {
          type: "richInline",
          ui: {
            control: "rich-inline",
            label: i18n("blocks.builtin.tabs.tab_label"),
          },
        },
      },
      ui: { label: i18n("blocks.builtin.tabs.tab") },
    },
  },
})
export default class Tabs extends Component {
  @tracked activeIndex = 0;

  /**
   * The stored label value for a child (may be empty). `RichTextRenderer`
   * normalises `undefined` to an empty field.
   *
   * @param {Object} child - The panel child entry.
   * @returns {*}
   */
  labelValue = (child) => child.containerArgs?.tab?.label;

  /**
   * The "Tab N" fallback shown when a child has no label — used as the live
   * strip text for an empty label and as the inline-editor placeholder.
   *
   * @param {number} index - The zero-based panel index.
   * @returns {string}
   */
  fallbackLabel = (index) =>
    i18n("blocks.builtin.tabs.tab_number", { number: index + 1 });

  /** @returns {boolean} Whether the editor wants every panel revealed. */
  get isEditing() {
    return debugHooks.isEditPresentation;
  }

  /** @returns {Array<Object>} The panel child entries. */
  get panels() {
    return this.args.children ?? [];
  }

  /**
   * The active index clamped to the current child count, so a stale
   * `activeIndex` (e.g. after a panel is removed) never points past the end.
   *
   * @returns {number}
   */
  get activePanelIndex() {
    const count = this.panels.length;
    if (count === 0) {
      return 0;
    }
    return Math.min(Math.max(this.activeIndex, 0), count - 1);
  }

  /** @returns {Object | undefined} The child shown on the live page. */
  get activePanel() {
    return this.panels[this.activePanelIndex];
  }

  /** @returns {string} Root class carrying the strip-alignment modifier. */
  get rootClass() {
    const align = VALID_ALIGNS.includes(this.args.align)
      ? this.args.align
      : "start";
    return `d-block-tabs d-block-tabs--align-${align}`;
  }

  @action
  selectTab(index) {
    this.activeIndex = index;
  }

  <template>
    {{#if this.isEditing}}
      {{! Editing: reveal every panel stacked so each child is directly
          selectable and editable, while the strip stays visible so labels can
          be edited in place. Each label span carries the `data-wf-container-arg-*`
          markers external editing tooling keys off to start an inline-edit
          session on the child's `containerArgs.tab.label`. }}
      <div class="{{this.rootClass}} d-block-tabs--editing">
        <div class="d-block-tabs__strip" role="tablist">
          {{#each this.panels key="key" as |child index|}}
            <span
              class="d-block-tabs__tab"
              role="tab"
              data-wf-container-arg-key={{child.key}}
              data-wf-container-arg-namespace="tab"
              data-wf-container-arg-field="label"
            >
              <RichTextRenderer
                @arg="label"
                @schema="plain"
                @value={{this.labelValue child}}
                @placeholder={{this.fallbackLabel index}}
                as |R|
              >
                <R.Content />
              </RichTextRenderer>
            </span>
          {{/each}}
        </div>

        <div class="d-block-tabs__panels">
          {{#each this.panels key="key" as |child index|}}
            <div
              class="d-block-tabs__panel"
              role="tabpanel"
              data-tab-index={{index}}
            >
              <child.Component />
            </div>
          {{/each}}
        </div>
      </div>
    {{else}}
      <div class={{this.rootClass}}>
        <div class="d-block-tabs__strip" role="tablist">
          {{#each this.panels key="key" as |child index|}}
            <button
              type="button"
              class="d-block-tabs__tab
                {{if (eq this.activePanelIndex index) 'is-active'}}"
              role="tab"
              aria-selected={{if
                (eq this.activePanelIndex index)
                "true"
                "false"
              }}
              {{on "click" (fn this.selectTab index)}}
            >
              <RichTextRenderer
                @arg="label"
                @schema="plain"
                @value={{this.labelValue child}}
                as |R|
              >
                {{#if R.isEmpty}}
                  {{this.fallbackLabel index}}
                {{else}}
                  <R.Content />
                {{/if}}
              </RichTextRenderer>
            </button>
          {{/each}}
        </div>

        {{#if this.activePanel}}
          <div class="d-block-tabs__panels">
            <div class="d-block-tabs__panel" role="tabpanel">
              <this.activePanel.Component />
            </div>
          </div>
        {{/if}}
      </div>
    {{/if}}
  </template>
}
