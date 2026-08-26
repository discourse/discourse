import DTooltip from "discourse/float-kit/components/d-tooltip";
import { not } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DShortcut from "discourse/ui-kit/d-shortcut";
import { i18n } from "discourse-i18n";

function titleWithShortcut(key, label) {
  const title = i18n(`discourse_workflows.canvas.${key}`);
  return label ? `${title} [${label}]` : title;
}

export default <template>
  <div class="workflows-canvas__controls">
    <DShortcut @keys="mod+z" as |shortcut|>
      <DTooltip
        @identifier="workflow-canvas-undo"
        @content={{titleWithShortcut "undo" shortcut.label}}
      >
        <:trigger>
          <DButton
            class="btn-flat btn-small"
            aria-keyshortcuts={{shortcut.aria}}
            @action={{@onUndo}}
            @disabled={{not @canUndo}}
            @icon="arrow-rotate-left"
          />
        </:trigger>
      </DTooltip>
    </DShortcut>
    <DShortcut @keys="mod+y" as |shortcut|>
      <DTooltip
        @identifier="workflow-canvas-redo"
        @content={{titleWithShortcut "redo" shortcut.label}}
      >
        <:trigger>
          <DButton
            class="btn-flat btn-small"
            aria-keyshortcuts={{shortcut.aria}}
            @action={{@onRedo}}
            @disabled={{not @canRedo}}
            @icon="arrow-rotate-right"
          />
        </:trigger>
      </DTooltip>
    </DShortcut>
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
