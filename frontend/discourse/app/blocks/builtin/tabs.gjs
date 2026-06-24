// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { next } from "@ember/runloop";
import { modifier } from "ember-modifier";
import { block } from "discourse/blocks";
import { debugHooks } from "discourse/lib/blocks/-internals/debug-hooks";
import RichTextRenderer from "discourse/lib/blocks/-internals/rich-text-renderer";
import { and, eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const VALID_ALIGNS = ["start", "center", "end"];

/**
 * A tabbed container: a horizontal strip of labels over a stack of panels,
 * showing one panel at a time. Each panel is a `layout` block (see
 * `childBlocks`), so a tab is a rich, grid-capable container.
 *
 * Each panel's tab label lives in the child's `containerArgs.tab.label` — the
 * parent-readable per-child metadata channel — because a container never
 * receives its children's own args. The `tabs` block reads it to build the
 * strip, falling back to "Tab N" when a child has no label yet.
 *
 * The tabs stay functional in an edit-driven context: only the active panel is
 * shown, and switching tabs reveals each panel's content for editing in turn —
 * the same one-at-a-time presentation as the live page. Under the ambient
 * "edit presentation" capability the block additionally renders an append
 * affordance at the end of the strip and marks each label as editable in place.
 */
@block("tabs", {
  container: true,
  displayName: "Tabs",
  icon: "table-columns",
  category: "Layout",
  description: "A tabbed container — one panel of blocks shown at a time.",
  // Each panel is itself a `layout` block, so a tab is a rich container out of
  // the box. The allow-list is validator-enforced; edit-driven tooling wraps any
  // other block dropped in as a panel to keep this invariant.
  childBlocks: ["layout"],
  args: {
    align: {
      type: "string",
      default: "start",
      enum: VALID_ALIGNS,
      ui: {
        control: "radio-group",
        label: i18n("blocks.builtin.tabs.align"),
        optionIcons: {
          start: "wf-align-left",
          center: "wf-align-center",
          end: "wf-align-right",
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

  /**
   * Activates a freshly added tab. A panel is only ever added to this container
   * as a new tab, so a growth in the child count means a tab was just appended —
   * switch to it, so an author who adds a tab lands on the (empty) panel they
   * just created rather than staying on the old one.
   *
   * `#previousPanelCount` starts null so the very first render (0 → N) is not
   * mistaken for growth; the assignment is deferred via `next` because it sets
   * `activeIndex`, which the same render reads.
   */
  syncActiveOnAdd = modifier((element, [count]) => {
    const total = Number(count);
    if (this.#previousPanelCount !== null && total > this.#previousPanelCount) {
      next(() => (this.activeIndex = total - 1));
    }
    this.#previousPanelCount = total;
  });

  /** @type {number | null} */
  #previousPanelCount = null;

  /**
   * @returns {boolean} Whether the ambient edit-presentation capability is set,
   *   so the block shows its in-place editing affordances (append + labels).
   */
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

  /** @returns {Object | undefined} The single child currently shown. */
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
    <div class={{this.rootClass}} {{this.syncActiveOnAdd this.panels.length}}>
      <div class="d-block-tabs__strip">
        {{! The tabs live in their own tablist so the editor-only append
            affordance can sit in the strip without being inside the tablist
            (a tablist holds only tabs). In an edit-driven context each tab
            carries its panel key so a click can select that panel's layout;
            the inline-edit markers + editable region are added ONLY to the
            active tab, so the label of the tab you're on can be edited in place
            while the others stay plain. All these attributes are omitted on the
            live page. }}
        <div class="d-block-tabs__tablist" role="tablist">
          {{#each this.panels key="key" as |child index|}}
            {{#let (eq this.activePanelIndex index) as |isActive|}}
              <button
                type="button"
                class="d-block-tabs__tab {{if isActive 'is-active'}}"
                role="tab"
                aria-selected={{if isActive "true" "false"}}
                data-wf-tab-panel-key={{if this.isEditing child.key}}
                data-wf-container-arg-key={{if
                  (and this.isEditing isActive)
                  child.key
                }}
                data-wf-container-arg-namespace={{if
                  (and this.isEditing isActive)
                  "tab"
                }}
                data-wf-container-arg-field={{if
                  (and this.isEditing isActive)
                  "label"
                }}
                {{on "click" (fn this.selectTab index)}}
              >
                <RichTextRenderer
                  @arg="label"
                  @schema="plain"
                  @value={{this.labelValue child}}
                  @placeholder={{this.fallbackLabel index}}
                  as |R|
                >
                  {{#if this.isEditing}}
                    {{! Editing: render the editable region for EVERY tab (even
                        when empty, so an unlabelled tab can still be clicked
                        into — the placeholder shows the "Tab N" hint). Gating
                        this on the active tab instead would move `<R.Content/>`
                        between conditional branches when a tab activates, which
                        makes Glimmer destroy + rebuild the just-clicked span —
                        detaching it before edit-driven click handling resolves
                        it, so selecting an inactive tab by its text silently
                        failed.
                        Which tab is the inline-edit TARGET is carried by the
                        `data-wf-container-arg-*` attributes below (active-only),
                        not by this branch. }}
                    <R.Content />
                  {{else if R.isEmpty}}
                    {{this.fallbackLabel index}}
                  {{else}}
                    <R.Content />
                  {{/if}}
                </RichTextRenderer>
              </button>
            {{/let}}
          {{/each}}
        </div>

        {{#if this.isEditing}}
          {{! Append-tab affordance, shown only under edit presentation. It
              carries no behaviour here; external edit-driven tooling detects
              the data attribute and appends a new panel. }}
          <button
            type="button"
            class="d-block-tabs__add-tab"
            data-wf-append-child="true"
            aria-label={{i18n "blocks.builtin.tabs.add_tab"}}
          >
            {{dIcon "plus"}}
          </button>
        {{/if}}
      </div>

      {{#if this.activePanel}}
        <div class="d-block-tabs__panels">
          <div class="d-block-tabs__panel" role="tabpanel">
            <this.activePanel.Component />
          </div>
        </div>
      {{/if}}
    </div>
  </template>
}
