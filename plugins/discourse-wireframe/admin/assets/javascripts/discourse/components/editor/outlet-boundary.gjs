// @ts-check
import dIcon from "discourse/ui-kit/helpers/d-icon";
import containerDropTarget from "../../modifiers/container-drop-target";
import EditorEmptyOutletDropZone from "./editor-empty-outlet-drop-zone";

/**
 * Outlet boundary chrome rendered around each `<BlockOutlet>` when the
 * editor is active. Wired via `DEBUG_CALLBACK.OUTLET_INFO_COMPONENT` in
 * the api-initializer.
 *
 * The host BlockOutlet curries this component with `{ outletName,
 * blockCount, outletArgs, error }` and renders it; we add a small label
 * badge above the outlet content and yield the children unchanged.
 *
 * The boundary div is itself a stack-mode drop container so the palette
 * can drop multiple top-level blocks into the outlet (the chrome of an
 * existing top-level block only covers drops INSIDE that block — without
 * this modifier there was no way to add a second sibling at the outlet
 * level once the first block existed). `containerKey` is omitted (defaults
 * to `null`) so `container-drop-target.js` recognises this as an outlet
 * root and dispatches inserts/moves against `outletName` alone.
 *
 * When `blockCount === 0`, the `BlockOutletRootContainer` renders
 * nothing, so we still render `<EditorEmptyOutletDropZone>` as a pure
 * visual affordance (its own dragdrop handlers were removed — drops are
 * handled by THIS boundary's modifier).
 */
<template>
  <div
    class="wireframe-outlet-boundary"
    data-outlet-name={{@outletName}}
    {{containerDropTarget mode="stack" outletName=@outletName}}
  >
    <span class="wireframe-outlet-boundary__badge">
      {{dIcon "cubes"}}
      <span>{{@outletName}}</span>
      {{#if @blockCount}}
        <span class="wireframe-outlet-boundary__count">·
          {{@blockCount}}</span>
      {{/if}}
    </span>
    {{yield}}
    {{#unless @blockCount}}
      <EditorEmptyOutletDropZone @outletName={{@outletName}} />
    {{/unless}}
  </div>
</template>
