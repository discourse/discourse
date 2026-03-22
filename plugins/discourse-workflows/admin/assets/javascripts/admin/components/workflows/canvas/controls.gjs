import DButton from "discourse/components/d-button";
import { translateModKey } from "discourse/lib/utilities";
import { not } from "discourse/truth-helpers";
import { i18n } from "discourse-i18n";

function undoTitle() {
  return `${i18n("discourse_workflows.canvas.undo")} [${translateModKey("Meta+Z")}]`;
}

function redoTitle() {
  return `${i18n("discourse_workflows.canvas.redo")} [${translateModKey("Meta+Y")}]`;
}

<template>
  <div class="workflows-canvas__controls">
    <DButton
      @action={{@onUndo}}
      @icon="arrow-rotate-left"
      @disabled={{not @canUndo}}
      @translatedTitle={{(undoTitle)}}
      class="btn-flat btn-small"
    />
    <DButton
      @action={{@onRedo}}
      @icon="arrow-rotate-right"
      @disabled={{not @canRedo}}
      @translatedTitle={{(redoTitle)}}
      class="btn-flat btn-small"
    />
    <DButton
      @action={{@onZoomOut}}
      @icon="magnifying-glass-minus"
      @title="discourse_workflows.canvas.zoom_out"
      class="btn-flat btn-small"
    />
    <DButton
      @action={{@onZoomIn}}
      @icon="magnifying-glass-plus"
      @title="discourse_workflows.canvas.zoom_in"
      class="btn-flat btn-small"
    />
    <DButton
      @action={{@onFitToView}}
      @icon="expand"
      @title="discourse_workflows.canvas.zoom_to_fit"
      class="btn-flat btn-small"
    />
    <DButton
      @action={{@onAutoLayout}}
      @icon="broom"
      @title="discourse_workflows.canvas.auto_layout"
      class="btn-flat btn-small"
    />
  </div>
</template>
