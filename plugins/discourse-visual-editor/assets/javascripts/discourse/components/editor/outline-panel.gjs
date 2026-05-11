// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import didUpdate from "@ember/render-modifiers/modifiers/did-update";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import dragAndDropSource from "discourse/modifiers/drag-and-drop-source";
import dragAndDropTarget from "discourse/modifiers/drag-and-drop-target";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { walkAllOutlets } from "../../lib/walk-layout";

// Inline `padding-left` driven by tree depth. We use `trustHTML` because
// the value is a constant we compute (no user input), and Ember will
// otherwise warn about dynamic style bindings.
function rowPadding(depth) {
  return trustHTML(`padding-left: ${depth * 0.75}rem;`);
}

/**
 * Read-only outline of registered block outlet layouts. Renders one section
 * per outlet, each containing a flattened tree of its blocks. Clicking a row
 * mirrors the canvas: it sets the selected block in the editor service so the
 * inspector populates and the matching block on the canvas highlights.
 *
 * Phase 1 limitation: the underlying layout map is only exposed in DEBUG
 * builds (`_getOutletLayouts`). In production, the outline shows an empty
 * state. Phase 3 replaces the data source with a public API on
 * `services/blocks` once the layout resolution chain lands in core.
 */
export default class OutlinePanel extends Component {
  @service blocks;
  @service visualEditor;

  @tracked outlets = [];

  // Lazy `blockName -> metadata` index built on first selection. Since each
  // BlockChrome instance does the same lookup, a future Phase could promote
  // this to a shared service-level cache to avoid repeated registry walks.
  _metaIndex = null;

  @action
  async refresh() {
    this.outlets = await walkAllOutlets({ blocksService: this.blocks });
  }

  /**
   * Re-walks the outlets whenever a structural mutation lands. Reads the
   * service's monotonically-bumped `structuralVersion` so every move
   * triggers a fresh walk — `_structurallyEditedOutlets.size` would only
   * fire the first time an outlet is touched per session.
   *
   * The signal value itself is unused — the dependency is what matters.
   */
  get structuralVersion() {
    return this.visualEditor.structuralVersion;
  }

  /**
   * @param {string} outletName - The owning outlet's name (the row itself
   *   does not carry it; we read it from the outer group when the user
   *   clicks).
   * @param {Object} row - A row produced by `walkAllOutlets`.
   */
  @action
  selectRow(outletName, row) {
    this.visualEditor.selectBlock({
      key: row.blockKey,
      name: row.blockName,
      id: row.blockId,
      args: row.args,
      conditions: row.conditions,
      outletName,
      metadata: this.lookupMetadataFor(row.blockName),
    });
  }

  lookupMetadataFor(blockName) {
    if (!this._metaIndex) {
      this._metaIndex = new Map(
        this.blocks
          .listBlocksWithMetadata()
          .map(({ name, metadata }) => [name, metadata])
      );
    }
    return this._metaIndex.get(blockName) ?? null;
  }

  /**
   * Adapts the core `draggable-item` modifier's `{data, event}` shape into
   * the flat `{blockKey, outletName}` argument the editor service expects.
   */
  @action
  handleRowDragStart({ data }) {
    this.visualEditor.startDrag(data);
  }

  /**
   * Drop-target for an outline row. Maps every row drop into a `before`
   * move — the outline is a flat ordered list, so "drop on row X" reads
   * as "place above row X". (Modifier keys for after/inside semantics is
   * a Phase 6 polish item.) The target row reads its own `blockKey` /
   * `outletName` from the row arg via the `(fn …)` curry at the call
   * site; the source comes through the core modifier's payload.
   *
   * @param {string} outletName
   * @param {Object} row - Row produced by `walkAllOutlets`.
   * @param {{ source: { data: { blockKey: string } } }} target
   */
  @action
  applyRowDrop(outletName, row, target) {
    this.visualEditor.moveBlock({
      sourceKey: target.source.data.blockKey,
      targetKey: row.blockKey,
      position: "before",
      targetOutletName: outletName,
    });
    this.visualEditor.endDrag();
  }

  @action
  isRowDragSource(blockKey) {
    return this.visualEditor.dragSourceKey === blockKey;
  }

  <template>
    <div
      class="visual-editor-outline"
      {{didInsert this.refresh}}
      {{didUpdate
        this.refresh
        this.visualEditor.isActive
        this.structuralVersion
      }}
    >
      {{#if this.outlets.length}}
        {{#each this.outlets as |group|}}
          <div class="outline-outlet">
            <div class="outline-outlet__label">
              {{dIcon "cube"}}
              <span>{{group.outletName}}</span>
            </div>
            {{#each group.rows as |row|}}
              <div
                class={{dConcatClass
                  "outline-block"
                  (if
                    (this.visualEditor.isBlockSelected row.blockKey)
                    "--selected"
                  )
                  (if (this.isRowDragSource row.blockKey) "--dragging")
                }}
                role="button"
                tabindex="0"
                style={{rowPadding row.depth}}
                {{on "click" (fn this.selectRow group.outletName row)}}
                {{dragAndDropSource
                  kind="ve-block"
                  data=(hash blockKey=row.blockKey outletName=group.outletName)
                  onDragStart=this.handleRowDragStart
                  onDragEnd=this.visualEditor.endDrag
                }}
                {{dragAndDropTarget
                  accepts="ve-block"
                  position="before"
                  onDrop=(fn this.applyRowDrop group.outletName row)
                }}
              >
                {{#if row.hasChildren}}
                  {{dIcon "folder"}}
                {{else}}
                  {{dIcon "circle"}}
                {{/if}}
                <span>{{row.blockName}}</span>
                {{#if row.blockId}}
                  <span class="outline-block__id">#{{row.blockId}}</span>
                {{/if}}
              </div>
            {{/each}}
          </div>
        {{/each}}
      {{else}}
        <div class="panel-empty">{{i18n "visual_editor.outline.empty"}}</div>
      {{/if}}
    </div>
  </template>
}
