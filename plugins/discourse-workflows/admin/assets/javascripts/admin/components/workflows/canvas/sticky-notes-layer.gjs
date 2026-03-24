import { fn } from "@ember/helper";
import { htmlSafe } from "@ember/template";
import { eq } from "discourse/truth-helpers";
import StickyNote from "./sticky-note";

function transformStyle(t) {
  if (!t) {
    return "";
  }
  const x = Number(t.x) || 0;
  const y = Number(t.y) || 0;
  const k = Number(t.k) || 1;
  return htmlSafe(
    `transform:translate(${x}px,${y}px) scale(${k});transform-origin:0 0;`
  );
}

<template>
  <div class="workflow-sticky-notes-layer">
    <div
      class="workflow-sticky-notes-layer__transform"
      style={{transformStyle @areaTransform}}
    >
      {{#each @stickyNotes key="clientId" as |note|}}
        <StickyNote
          @note={{note}}
          @isSelected={{eq @selectedStickyNoteId note.clientId}}
          @zoom={{@areaTransform.k}}
          @onSelect={{fn @onSelect note.clientId}}
          @onDragStart={{@onDragStart}}
          @onMove={{fn @onMove note.clientId}}
          @onResize={{fn @onResize note.clientId}}
          @onUpdateText={{fn @onUpdateText note.clientId}}
          @onChangeColor={{fn @onChangeColor note.clientId}}
          @onDelete={{fn @onDelete note.clientId}}
          @onDragEnd={{@onDragEnd}}
        />
      {{/each}}
    </div>
  </div>
</template>
