import DTooltip from "discourse/float-kit/components/d-tooltip";
import { translateModKey } from "discourse/lib/utilities";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

function undoTitle() {
  return `${i18n("discourse_workflows.canvas.undo")} [${translateModKey("Meta+Z")}]`;
}

function redoTitle() {
  return `${i18n("discourse_workflows.canvas.redo")} [${translateModKey("Meta+Y")}]`;
}

export default <template>
  <div class="workflows-canvas__controls">
    <DTooltip @identifier="workflow-canvas-undo" @content={{(undoTitle)}}>
      <:trigger>
        <DButton
          @action={{@onUndo}}
          @icon="arrow-rotate-left"
          @disabled={{not @canUndo}}
          class="btn-flat btn-small"
        />
      </:trigger>
    </DTooltip>
    <DTooltip @identifier="workflow-canvas-redo" @content={{(redoTitle)}}>
      <:trigger>
        <DButton
          @action={{@onRedo}}
          @icon="arrow-rotate-right"
          @disabled={{not @canRedo}}
          class="btn-flat btn-small"
        />
      </:trigger>
    </DTooltip>
    <DTooltip
      @identifier="workflow-canvas-zoom-out"
      @content={{i18n "discourse_workflows.canvas.zoom_out"}}
    >
      <:trigger>
        <DButton
          @action={{@onZoomOut}}
          @icon="magnifying-glass-minus"
          class="btn-flat btn-small"
        />
      </:trigger>
    </DTooltip>
    <DTooltip
      @identifier="workflow-canvas-zoom-in"
      @content={{i18n "discourse_workflows.canvas.zoom_in"}}
    >
      <:trigger>
        <DButton
          @action={{@onZoomIn}}
          @icon="magnifying-glass-plus"
          class="btn-flat btn-small"
        />
      </:trigger>
    </DTooltip>
    <DTooltip
      @identifier="workflow-canvas-zoom-to-fit"
      @content={{i18n "discourse_workflows.canvas.zoom_to_fit"}}
    >
      <:trigger>
        <DButton
          @action={{@onFitToView}}
          @icon="expand"
          class="btn-flat btn-small"
        />
      </:trigger>
    </DTooltip>
    <DTooltip
      @identifier="workflow-canvas-auto-layout"
      @content={{i18n "discourse_workflows.canvas.auto_layout"}}
    >
      <:trigger>
        <DButton
          @action={{@onAutoLayout}}
          @icon="broom"
          class="btn-flat btn-small"
        />
      </:trigger>
    </DTooltip>
  </div>
</template>
