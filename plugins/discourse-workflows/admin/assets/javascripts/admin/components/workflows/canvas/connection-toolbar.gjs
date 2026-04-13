import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import CanvasHoverToolbar from "./hover-toolbar";

function stopAndCall(callback, e) {
  e.stopPropagation();
  callback?.();
}

<template>
  <CanvasHoverToolbar
    @hoverQuery=".workflow-connection__hit"
    @visibilityQuery=".workflow-connection__toolbar-fo"
    @inline={{true}}
  >
    <button
      type="button"
      class="workflow-canvas-toolbar__btn"
      title={{i18n "discourse_workflows.canvas.add_step"}}
      {{on "click" (fn stopAndCall @onAdd)}}
    >
      {{icon "plus"}}
    </button>
    <button
      type="button"
      class="workflow-canvas-toolbar__btn"
      title={{i18n "discourse_workflows.canvas.remove_connection"}}
      {{on "click" (fn stopAndCall @onDelete)}}
    >
      {{icon "trash-can"}}
    </button>
  </CanvasHoverToolbar>
</template>
