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
import type { ChildBlockResult } from "discourse/lib/blocks/-internals/types";
import { and, eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

const VALID_ALIGNS = ["start", "center", "end"];

interface TabsSignature {
  Args: {
    children?: ChildBlockResult[];
    align?: string;
  };
}

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
  thumbnail: () => import("discourse/blocks/thumbnails/tabs"),
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
            schema: "plain",
            label: i18n("blocks.builtin.tabs.tab_label"),
          },
        },
      },
      ui: { label: i18n("blocks.builtin.tabs.tab") },
    },
  },
})
export default class Tabs extends Component<TabsSignature> {
  /**
   * The key of the panel the author has activated, or `null` to fall back to the
   * first panel. Tracked by KEY rather than a positional index so reordering the
   * panels never shifts which one is active.
   */
  @tracked activeKey: string | null = null;

  /**
   * The stored label value for a child (may be empty). `RichTextRenderer`
   * normalises `undefined` to an empty field.
   *
   * @param child - The panel child entry.
   * @returns The stored label value, or `undefined` when none is set.
   */
  labelValue = (child: ChildBlockResult) =>
    (child.containerArgs?.tab as { label?: unknown } | undefined)?.label;

  /**
   * The "Tab N" fallback shown when a child has no label — used as the live
   * strip text for an empty label and as the inline-editor placeholder.
   *
   * @param index - The zero-based panel index.
   * @returns The localized "Tab N" label.
   */
  fallbackLabel = (index: number) =>
    i18n("blocks.builtin.tabs.tab_number", { number: index + 1 });

  /**
   * Activates a freshly added tab so an author lands on the panel they just
   * created. Tracks the SET of child keys across renders (not just the count),
   * so an insert ANYWHERE — not only an append — reveals the tab that was
   * actually added rather than always jumping to the last one. The assignment
   * is deferred via `next` because it sets `activeKey`, which the same render
   * reads; `#previousPanelKeys` starts null so the first render (0 → N) is not
   * mistaken for an insert.
   */
  revealAddedPanel = modifier<{
    Element: HTMLElement;
    Args: { Positional: [number] };
  }>(() => {
    const keys = this.panels.map((panel) => panel.key);
    if (this.#previousPanelKeys) {
      const added = keys.find((key) => !this.#previousPanelKeys.has(key));
      if (added != null) {
        next(() => (this.activeKey = added));
      }
    }
    this.#previousPanelKeys = new Set(keys);
  });

  #previousPanelKeys: Set<string> | null = null;

  /**
   * Whether the ambient edit-presentation capability is set, so the block
   * shows its in-place editing affordances (append + labels).
   *
   * @returns Whether an editing context is active.
   */
  get isEditing() {
    return debugHooks.isEditPresentation;
  }

  /**
   * The panel child entries.
   *
   * @returns The tab panels.
   */
  get panels(): ChildBlockResult[] {
    return this.args.children ?? [];
  }

  /**
   * The key of the panel currently shown — the activated key while it still
   * matches a panel, otherwise the first panel's key. Resolving by key (rather
   * than a stored index) keeps the right panel active across reorders, and
   * falls back cleanly when the activated panel was removed.
   *
   * @returns The active panel's key, or `undefined` when there are no panels.
   */
  get activePanelKey() {
    const panels = this.panels;
    if (
      this.activeKey &&
      panels.some((panel) => panel.key === this.activeKey)
    ) {
      return this.activeKey;
    }
    return panels[0]?.key;
  }

  /**
   * The single child currently shown.
   *
   * @returns The active panel entry, or `undefined` when there are no panels.
   */
  get activePanel() {
    return this.panels.find((panel) => panel.key === this.activePanelKey);
  }

  /**
   * Root class carrying the strip-alignment modifier.
   *
   * @returns The root class list.
   */
  get rootClass() {
    const align = VALID_ALIGNS.includes(this.args.align)
      ? this.args.align
      : "start";
    return `d-block-tabs d-block-tabs--align-${align}`;
  }

  @action
  selectTab(key: string) {
    this.activeKey = key;
  }

  <template>
    <div class={{this.rootClass}} {{this.revealAddedPanel this.panels.length}}>
      <div class="d-block-tabs__strip">
        {{! The tabs live in their own tablist so the editor-only append
            affordance can sit in the strip without being inside the tablist
            (a tablist holds only tabs). In an edit-driven context each tab
            carries its panel key so a click can select that panel's layout;
            the inline-edit markers + editable region are added ONLY to the
            active tab, so the label of the tab you're on can be edited in place
            while the others stay plain.

            In an edit-driven context the tablist also doubles as a horizontal
            insert track: it is marked as a drop container on the x axis, and
            each tab carries the panel's key so external tooling can resolve a
            drop between tabs to a new panel at that position. The child-noun
            attributes let the drop messages read in tab terms. All these
            attributes are omitted on the live page. }}
        <div
          class="d-block-tabs__tablist"
          role="tablist"
          data-wf-drop-container={{if this.isEditing "true"}}
          data-wf-drop-axis={{if this.isEditing "x"}}
          data-wf-child-noun={{if
            this.isEditing
            (i18n "blocks.builtin.tabs.tab_noun")
          }}
          data-wf-child-noun-plural={{if
            this.isEditing
            (i18n "blocks.builtin.tabs.tab_noun_plural")
          }}
        >
          {{#each this.panels key="key" as |child index|}}
            {{#let (eq child.key this.activePanelKey) as |isActive|}}
              <button
                type="button"
                class="d-block-tabs__tab {{if isActive 'is-active'}}"
                role="tab"
                aria-selected={{if isActive "true" "false"}}
                data-wf-tab-panel-key={{if this.isEditing child.key}}
                data-wf-drop-child-key={{if this.isEditing child.key}}
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
                {{on "click" (fn this.selectTab child.key)}}
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
                        this on the active tab instead would move the content
                        component between conditional branches when a tab
                        activates, which makes Glimmer destroy and rebuild the
                        just-clicked span — detaching it before edit-driven
                        click handling resolves it, so selecting an inactive tab
                        by its text silently failed.
                        Which tab is the inline-edit TARGET is carried by the
                        container-arg data attributes below (active-only),
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
