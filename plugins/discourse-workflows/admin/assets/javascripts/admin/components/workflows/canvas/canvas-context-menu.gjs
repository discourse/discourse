import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { trustHTML } from "@ember/template";
import DButton from "discourse/components/d-button";
import { i18n } from "discourse-i18n";

export default class CanvasContextMenu extends Component {
  @tracked contextMenu = null;

  constructor() {
    super(...arguments);
    this.args.onRegister?.(this);
  }

  get style() {
    if (!this.contextMenu || !this.args.canvasElement) {
      return "";
    }
    const rect = this.args.canvasElement.getBoundingClientRect();
    const left = this.contextMenu.screenX - rect.left;
    const top = this.contextMenu.screenY - rect.top;
    return trustHTML(`left: ${left}px; top: ${top}px`);
  }

  @action
  open(event) {
    event.preventDefault();
    this.contextMenu = null;

    if (!this.args.rete) {
      return;
    }

    const nodeEl = event.target.closest(".workflow-rete-node");
    if (nodeEl) {
      const clientId = nodeEl.dataset.clientId;
      if (clientId && !this.args.rete.getSelectedIds().nodeIds.has(clientId)) {
        this.args.rete.selectableNodes.select(clientId, false);
      }
      this.contextMenu = {
        nodeId: clientId,
        screenX: event.clientX,
        screenY: event.clientY,
      };
      return;
    }

    const rect = this.args.containerElement.getBoundingClientRect();
    const canvasPos = this.args.rete.containerToCanvas(
      event.clientX - rect.left,
      event.clientY - rect.top
    );
    this.contextMenu = {
      isCanvas: true,
      canvasPos,
      screenX: event.clientX,
      screenY: event.clientY,
    };
  }

  @action
  close() {
    this.contextMenu = null;
  }

  @action
  editNode() {
    const nodeId = this.contextMenu.nodeId;
    this.contextMenu = null;
    this.args.onEditNode?.(nodeId);
  }

  @action
  deleteNode() {
    this.contextMenu = null;
    this.args.onDeleteSelected?.();
  }

  @action
  addNode() {
    const canvasPos = this.contextMenu?.canvasPos;
    this.contextMenu = null;
    if (canvasPos) {
      this.args.onOpenNodePanel?.(canvasPos);
    }
  }

  @action
  addStickyNote() {
    const canvasPos = this.contextMenu?.canvasPos;
    this.contextMenu = null;
    if (canvasPos) {
      this.args.onAddStickyNote?.(canvasPos);
    }
  }

  <template>
    {{#if this.contextMenu}}
      <div class="workflows-canvas__context-menu" style={{this.style}}>
        {{#if this.contextMenu.isCanvas}}
          <DButton
            @action={{this.addNode}}
            @icon="plus"
            @translatedLabel={{i18n "discourse_workflows.canvas.add_step"}}
            class="btn-transparent workflows-canvas__context-menu-item"
          />
          <DButton
            @action={{this.addStickyNote}}
            @icon="note-sticky"
            @translatedLabel={{i18n "discourse_workflows.sticky_note.add"}}
            class="btn-transparent workflows-canvas__context-menu-item"
          />
        {{else}}
          <DButton
            @action={{this.editNode}}
            @icon="pencil"
            @translatedLabel={{i18n "discourse_workflows.edit"}}
            class="btn-transparent workflows-canvas__context-menu-item"
          />
          <DButton
            @action={{this.deleteNode}}
            @icon="trash-can"
            @translatedLabel={{i18n "discourse_workflows.delete"}}
            class="btn-transparent btn-danger workflows-canvas__context-menu-item"
          />
        {{/if}}
      </div>
    {{/if}}
  </template>
}
