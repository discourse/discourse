// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import dragAndDropSource from "discourse/modifiers/drag-and-drop-source";
import dragAndDropTarget from "discourse/modifiers/drag-and-drop-target";
import { i18n } from "discourse-i18n";

/**
 * Wraps every rendered block while the editor is active so the canvas can
 * show selection chrome (an outline plus a corner handle when selected) and
 * drag-and-drop affordances (a drag handle + drop zones around the block).
 *
 * Curried into the block render path via the `BLOCK_DEBUG` debug-hook from
 * the api-initializer. When the editor is inactive, only the wrapped block
 * renders — no extra DOM and no event interception, so the host page
 * behaves exactly as it would without the plugin.
 *
 * Drag-and-drop model (chosen because HTML5 DnD on nested-draggable
 * elements is unreliable):
 *   - The chrome itself is NOT draggable. The `.visual-editor-block-handle`
 *     corner badge IS the drag source.
 *   - The handle is rendered always; CSS hides it until the chrome is
 *     hovered or selected. That way users grab it with one gesture, not
 *     two.
 *   - Drop zones (before/after siblings, optional inside-container) are
 *     siblings of the wrapped component within the chrome. They occupy
 *     real layout space (4px) at all times while the editor is active so
 *     hit-testing is reliable from the very first dragenter.
 */
export default class BlockChrome extends Component {
  @service blocks;
  @service visualEditor;

  /**
   * Block metadata (description, namespace, isContainer, args schema, etc.)
   * for the wrapped block, or `null` if the registry has no entry for this
   * block name.
   *
   * `@cached` memoises the lookup per component instance. A future Phase
   * could promote this to a shared service-level cache to avoid every
   * rendered block walking the registry on first access.
   */
  @cached
  get metadata() {
    const index = this.blocks
      .listBlocksWithMetadata()
      .reduce((m, e) => m.set(e.name, e.metadata), new Map());
    return index.get(this.args.blockName) ?? null;
  }

  /** @returns {boolean} */
  get isSelected() {
    return this.visualEditor.isBlockSelected(this.args.blockKey);
  }

  /** @returns {boolean} */
  get isContainer() {
    return this.metadata?.isContainer ?? false;
  }

  /** @returns {string} */
  get displayName() {
    return this.metadata?.shortName ?? this.args.blockName;
  }

  /**
   * Captures the click only when editor is active. Stops propagation so the
   * host page's own click handlers (links, buttons inside the block) don't
   * fire while the user is editing.
   */
  @action
  onClick(event) {
    if (!this.visualEditor.isActive) {
      return;
    }
    event.preventDefault();
    event.stopPropagation();
    this.visualEditor.selectBlock({
      key: this.args.blockKey,
      name: this.args.blockName,
      id: this.args.blockId,
      args: this.args.blockArgs,
      containerArgs: this.args.containerArgs,
      conditions: this.args.conditions,
      outletArgs: this.args.outletArgs,
      outletName: this.args.outletName,
      metadata: this.metadata,
    });
  }

  /**
   * Whether a given before/after/inside drop zone for *this* block is
   * currently active (cursor hovering over it during a drag). Drives the
   * `--active` class so the user sees where the drop will land.
   */
  @action
  isDropZoneActive(position) {
    const t = this.visualEditor.activeDropTarget;
    return (
      t?.targetKey === this.args.blockKey &&
      t?.position === position &&
      t?.outletName === this.args.outletName
    );
  }

  /**
   * Drop-target gate — rejects drops that would re-insert a block onto its
   * own zones (a no-op anyway) and consults the editor service for outlet-
   * level allowed/denied checks. The modifier already filters drags whose
   * `kind` isn't `"ve-block"`, so this fires only for our own payloads.
   */
  @action
  canDropOnThisBlock({ source }) {
    if (source?.data?.blockKey === this.args.blockKey) {
      return false;
    }
    return this.visualEditor.canDropAt({
      targetOutletName: this.args.outletName,
    });
  }

  /**
   * Adapts the core modifier's `{data, event}` drag-start payload into the
   * shape `visualEditor.startDrag` expects (a flat
   * `{blockKey, outletName}`). The data was attached at the `draggable-item`
   * call site as `(hash blockKey=… outletName=…)`.
   */
  @action
  handleDragStart({ data }) {
    this.visualEditor.startDrag(data);
  }

  /**
   * Forwards the drop-target's `position` straight to the service so the
   * canvas can highlight the matching zone. The core modifier passes
   * `position` in the callback payload (lifted from the modifier's own
   * `position` arg) — we do NOT read `event.currentTarget.dataset`,
   * because by the time `dragLeave` fires from inside its 10ms deferred
   * clear the browser has already nulled out `event.currentTarget`.
   */
  @action
  handleZoneDragEnter({ position }) {
    this.visualEditor.setActiveDropTarget({
      targetKey: this.args.blockKey,
      position,
      outletName: this.args.outletName,
    });
  }

  @action
  handleZoneDragLeave({ position }) {
    this.visualEditor.clearActiveDropTarget({
      targetKey: this.args.blockKey,
      position,
    });
  }

  /**
   * Translates a drop-zone payload into a `moveBlock` call. `position`
   * comes from the modifier (matches what we passed in via the `position`
   * arg); the dragged block's key lives at `source.data.blockKey`.
   */
  @action
  applyDrop({ source, position }) {
    this.visualEditor.moveBlock({
      sourceKey: source.data.blockKey,
      targetKey: this.args.blockKey,
      position,
      targetOutletName: this.args.outletName,
    });
    this.visualEditor.endDrag();
  }

  <template>
    {{#if this.visualEditor.isActive}}
      {{! Outer wrapper hosts the sibling drop zones (before/after) and the
        bordered frame in between. The dotted block-chrome border is on the
        inner element so the before/after zones render visually OUTSIDE the
        block — matching the move semantics ("place adjacent to this block
        at the parent's level"). Inside zones (containers only) sit within
        the frame, signalling "place as the container's first child". }}
      <div class="visual-editor-block-chrome-wrapper">
        <div
          class={{concatClass
            "visual-editor-drop-zone --before"
            (if (this.isDropZoneActive "before") "--active")
          }}
          data-ve-position="before"
          {{dragAndDropTarget
            accepts="ve-block"
            position="before"
            canDrop=this.canDropOnThisBlock
            onDragEnter=this.handleZoneDragEnter
            onDragLeave=this.handleZoneDragLeave
            onDrop=this.applyDrop
          }}
        ></div>

        <div
          class={{concatClass
            "visual-editor-block-chrome"
            (if this.isSelected "--selected")
            (if this.isContainer "--container")
          }}
          data-ve-block-name={{@blockName}}
          data-ve-block-key={{@blockKey}}
          {{on "click" this.onClick}}
          role="button"
          tabindex="0"
        >
          {{! The handle is the ONLY drag source. Always rendered (CSS hides
            it until the chrome is hovered or selected) so the modifier's
            registration is stable across hover transitions. }}
          <span
            class="visual-editor-block-handle"
            title={{i18n "visual_editor.canvas.drag_handle_title"}}
            {{dragAndDropSource
              kind="ve-block"
              data=(hash blockKey=@blockKey outletName=@outletName)
              onDragStart=this.handleDragStart
              onDragEnd=this.visualEditor.endDrag
            }}
          >
            {{icon "grip-lines"}}
            <span>{{this.displayName}}</span>
          </span>

          <@WrappedComponent />

          {{#if this.isContainer}}
            <div
              class={{concatClass
                "visual-editor-drop-zone --inside"
                (if (this.isDropZoneActive "inside") "--active")
              }}
              data-ve-position="inside"
              {{dragAndDropTarget
                accepts="ve-block"
                position="inside"
                canDrop=this.canDropOnThisBlock
                onDragEnter=this.handleZoneDragEnter
                onDragLeave=this.handleZoneDragLeave
                onDrop=this.applyDrop
              }}
            >
              <span class="visual-editor-drop-zone__label">{{i18n
                  "visual_editor.canvas.drop_inside"
                }}</span>
            </div>
          {{/if}}
        </div>

        <div
          class={{concatClass
            "visual-editor-drop-zone --after"
            (if (this.isDropZoneActive "after") "--active")
          }}
          data-ve-position="after"
          {{dragAndDropTarget
            accepts="ve-block"
            position="after"
            canDrop=this.canDropOnThisBlock
            onDragEnter=this.handleZoneDragEnter
            onDragLeave=this.handleZoneDragLeave
            onDrop=this.applyDrop
          }}
        ></div>
      </div>
    {{else}}
      <@WrappedComponent />
    {{/if}}
  </template>
}
