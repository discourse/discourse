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
        @content={{titleWithShortcut "undo" shortcut.label}}
        @identifier="workflow-canvas-undo"
      >
        <:trigger>
          <DButton
            aria-keyshortcuts={{shortcut.aria}}
            class="btn-flat btn-small"
            @action={{@onUndo}}
            @disabled={{not @canUndo}}
            @icon="arrow-rotate-left"
          />
        </:trigger>
      </DTooltip>
    </DShortcut>
    <DShortcut @keys="mod+y" as |shortcut|>
      <DTooltip
        @content={{titleWithShortcut "redo" shortcut.label}}
        @identifier="workflow-canvas-redo"
      >
        <:trigger>
          <DButton
            aria-keyshortcuts={{shortcut.aria}}
            class="btn-flat btn-small"
            @action={{@onRedo}}
            @disabled={{not @canRedo}}
            @icon="arrow-rotate-right"
          />
        </:trigger>
      </DTooltip>
    </DShortcut>
    <DTooltip
      @content={{i18n "discourse_workflows.canvas.zoom_out"}}
      @identifier="workflow-canvas-zoom-out"
    >
      <:trigger>
        <DButton
          class="btn-flat btn-small"
          @action={{@onZoomOut}}
          @icon="magnifying-glass-minus"
        />
      </:trigger>
    </DTooltip>
    <DTooltip
      @content={{i18n "discourse_workflows.canvas.zoom_in"}}
      @identifier="workflow-canvas-zoom-in"
    >
      <:trigger>
        <DButton
          class="btn-flat btn-small"
          @action={{@onZoomIn}}
          @icon="magnifying-glass-plus"
        />
      </:trigger>
    </DTooltip>
    <DTooltip
      @content={{i18n "discourse_workflows.canvas.zoom_to_fit"}}
      @identifier="workflow-canvas-zoom-to-fit"
    >
      <:trigger>
        <DButton
          class="btn-flat btn-small"
          @action={{@onFitToView}}
          @icon="expand"
        />
      </:trigger>
    </DTooltip>
    <DTooltip
      @content={{i18n "discourse_workflows.canvas.auto_layout"}}
      @identifier="workflow-canvas-auto-layout"
    >
      <:trigger>
        <DButton
          class="btn-flat btn-small"
          @action={{@onAutoLayout}}
          @icon="broom"
        />
      </:trigger>
    </DTooltip>
  </div>
</template>
