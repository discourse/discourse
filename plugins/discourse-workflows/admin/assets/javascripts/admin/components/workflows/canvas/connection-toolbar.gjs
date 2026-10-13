import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import CanvasHoverToolbar from "./hover-toolbar";

function stopAndCall(callback, e) {
  e.stopPropagation();
  callback?.();
}

export default <template>
  <CanvasHoverToolbar
    @hoverQuery=".workflow-connection__hit"
    @inline={{true}}
    @visibilityQuery=".workflow-connection__toolbar-fo"
  >
    <DTooltip
      @content={{i18n "discourse_workflows.canvas.add_step"}}
      @identifier="workflow-connection-add-step"
    >
      <:trigger>
        <button
          class="workflow-canvas-toolbar__btn"
          type="button"
          {{on "click" (fn stopAndCall @onAdd)}}
        >
          {{dIcon "plus"}}
        </button>
      </:trigger>
    </DTooltip>
    <DTooltip
      @content={{i18n "discourse_workflows.canvas.remove_connection"}}
      @identifier="workflow-connection-remove"
    >
      <:trigger>
        <button
          class="workflow-canvas-toolbar__btn"
          type="button"
          {{on "click" (fn stopAndCall @onDelete)}}
        >
          {{dIcon "trash-can"}}
        </button>
      </:trigger>
    </DTooltip>
  </CanvasHoverToolbar>
</template>
