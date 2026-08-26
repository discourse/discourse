import DTooltip from "discourse/float-kit/components/d-tooltip";
import { formatShortcut } from "discourse/lib/shortcut-format";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

const UNDO = formatShortcut("mod+z");
const REDO = formatShortcut("mod+y");

function undoTitle() {
  return `${i18n("discourse_workflows.canvas.undo")} [${UNDO.label}]`;
}

function redoTitle() {
  return `${i18n("discourse_workflows.canvas.redo")} [${REDO.label}]`;
}

export default <template>
  <div class="workflows-canvas__controls">
    <DTooltip @identifier="workflow-canvas-undo" @content={{(undoTitle)}}>
      <:trigger>
        <DButton
          class="btn-flat btn-small"
          aria-keyshortcuts={{UNDO.aria}}
          @action={{@onUndo}}
          @disabled={{not @canUndo}}
          @icon="arrow-rotate-left"
        />
      </:trigger>
    </DTooltip>
    <DTooltip @identifier="workflow-canvas-redo" @content={{(redoTitle)}}>
      <:trigger>
        <DButton
          class="btn-flat btn-small"
          aria-keyshortcuts={{REDO.aria}}
          @action={{@onRedo}}
          @disabled={{not @canRedo}}
          @icon="arrow-rotate-right"
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
