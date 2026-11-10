import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

/**
 * Shared so the modifier and every programmatic close name the same menu. `menu.close`
 * returns silently when an identifier matches nothing, so a typo in one of the close paths
 * would leave the menu open with nothing to catch it.
 */
export const CANVAS_CONTEXT_MENU_IDENTIFIER = "workflows-canvas-context-menu";

/** Builds a synchronous menu decision; selection never supplies the payload. */
export function decideCanvasContextMenu({ event, rete, containerElement }) {
  if (!rete) {
    return false;
  }

  const rect = containerElement.getBoundingClientRect();
  const canvasPos = rete.containerToCanvas(
    event.clientX - rect.left,
    event.clientY - rect.top
  );
  const nodeEl = event.target.closest(".workflow-rete-node");
  if (nodeEl) {
    const clientId = nodeEl.dataset.clientId;
    const selectedIds = rete.getSelectedIds();
    const useCurrentSelection = selectedIds.nodeIds.has(clientId);
    const selection = useCurrentSelection
      ? {
          nodeIds: [...selectedIds.nodeIds],
          stickyNoteIds: [...selectedIds.stickyNoteIds],
        }
      : { nodeIds: [clientId], stickyNoteIds: [] };

    if (clientId && !useCurrentSelection) {
      void rete.selectableNodes.select(clientId, false);
    }
    return {
      data: {
        nodeId: clientId,
        selection,
        isUnavailable: nodeEl.dataset.unavailable === "true",
        canvasPos,
      },
    };
  }

  return { data: { isCanvas: true, canvasPos } };
}

export default class CanvasContextMenu extends Component {
  @action
  addNode() {
    const canvasPos = this.args.data.canvasPos;
    this.args.close();
    if (canvasPos) {
      this.args.data.onOpenNodePanel?.(canvasPos);
    }
  }

  @action
  addStickyNote() {
    const canvasPos = this.args.data.canvasPos;
    this.args.close();
    if (canvasPos) {
      this.args.data.onAddStickyNote?.(canvasPos);
    }
  }

  @action
  copySelection() {
    const selection = this.args.data.selection;
    this.args.close();
    this.args.data.onCopy?.(selection);
  }

  @action
  cutSelection() {
    const selection = this.args.data.selection;
    this.args.close();
    this.args.data.onCut?.(selection);
  }

  @action
  deleteNode() {
    const selection = this.args.data.selection;
    this.args.close();
    this.args.data.onDeleteSelected?.(selection);
  }

  @action
  editNode() {
    const nodeId = this.args.data.nodeId;
    this.args.close();
    this.args.data.onEditNode?.(nodeId);
  }

  @action
  pasteSelection() {
    const canvasPos = this.args.data.canvasPos;
    this.args.close();
    this.args.data.onPaste?.(canvasPos);
  }

  <template>
    <div class="workflows-canvas__context-menu">
      {{#if @data.isCanvas}}
        <DButton
          class="btn-transparent workflows-canvas__context-menu-item"
          @action={{this.addNode}}
          @icon="plus"
          @translatedLabel={{i18n "discourse_workflows.canvas.add_step"}}
        />
        <DButton
          class="btn-transparent workflows-canvas__context-menu-item"
          @action={{this.addStickyNote}}
          @icon="note-sticky"
          @translatedLabel={{i18n "discourse_workflows.sticky_note.add"}}
        />
        <DButton
          class="btn-transparent workflows-canvas__context-menu-item"
          @action={{this.pasteSelection}}
          @icon="paste"
          @translatedLabel={{i18n "discourse_workflows.canvas.paste"}}
        />
      {{else}}
        {{#unless @data.isUnavailable}}
          <DButton
            class="btn-transparent workflows-canvas__context-menu-item"
            @action={{this.editNode}}
            @icon="pencil"
            @translatedLabel={{i18n "discourse_workflows.edit"}}
          />
        {{/unless}}
        <DButton
          class="btn-transparent workflows-canvas__context-menu-item"
          @action={{this.cutSelection}}
          @icon="scissors"
          @translatedLabel={{i18n "discourse_workflows.canvas.cut"}}
        />
        <DButton
          class="btn-transparent workflows-canvas__context-menu-item"
          @action={{this.copySelection}}
          @icon="copy"
          @translatedLabel={{i18n "discourse_workflows.canvas.copy"}}
        />
        <DButton
          class="btn-transparent workflows-canvas__context-menu-item"
          @action={{this.pasteSelection}}
          @icon="paste"
          @translatedLabel={{i18n "discourse_workflows.canvas.paste"}}
        />
        <DButton
          class="btn-transparent btn-danger workflows-canvas__context-menu-item"
          @action={{this.deleteNode}}
          @icon="trash-can"
          @translatedLabel={{i18n "discourse_workflows.delete"}}
        />
      {{/if}}
    </div>
  </template>
}
