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
    @visibilityQuery=".workflow-connection__toolbar-fo"
    @inline={{true}}
  >
    <DTooltip
      @identifier="workflow-connection-add-step"
      @content={{i18n "discourse_workflows.canvas.add_step"}}
    >
      <:trigger>
        <button
          type="button"
          class="workflow-canvas-toolbar__btn"
          {{on "click" (fn stopAndCall @onAdd)}}
        >
          {{dIcon "plus"}}
        </button>
      </:trigger>
    </DTooltip>
    <DTooltip
      @identifier="workflow-connection-remove"
      @content={{i18n "discourse_workflows.canvas.remove_connection"}}
    >
      <:trigger>
        <button
          type="button"
          class="workflow-canvas-toolbar__btn"
          {{on "click" (fn stopAndCall @onDelete)}}
        >
          {{dIcon "trash-can"}}
        </button>
      </:trigger>
    </DTooltip>
  </CanvasHoverToolbar>
</template>
