// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { buildBlockPalette } from "../../lib/palette";
import containerDropTarget from "../../modifiers/container-drop-target";
import EditorEmptyDropPlaceholder from "./editor-empty-drop-placeholder";

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
 * When `blockCount === 0`, `BlockOutletRootContainer` renders nothing,
 * so we render the shared `<EditorEmptyDropPlaceholder>` as a click-to-
 * insert affordance. Drops onto the bar are still handled by THIS
 * boundary's `containerDropTarget` modifier — the placeholder only
 * intercepts clicks, dragover bubbles up.
 */
export default class OutletBoundary extends Component {
  @service blocks;
  @service wireframe;

  @cached
  get palette() {
    return buildBlockPalette(this.blocks);
  }

  @action
  insertBlock(blockEntry) {
    this.wireframe.insertBlock({
      blockName: blockEntry.name,
      targetKey: null,
      position: "inside",
      targetOutletName: this.args.outletName,
    });
  }

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
        <EditorEmptyDropPlaceholder
          @hint={{i18n "wireframe.canvas.empty_outlet_hint"}}
          @palette={{this.palette}}
          @onPick={{this.insertBlock}}
        />
      {{/unless}}
    </div>
  </template>
}
