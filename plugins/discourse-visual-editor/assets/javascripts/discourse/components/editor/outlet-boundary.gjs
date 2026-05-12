// @ts-check
import dIcon from "discourse/ui-kit/helpers/d-icon";
import EditorEmptyOutletDropZone from "./editor-empty-outlet-drop-zone";

/**
 * Outlet boundary chrome rendered around each `<BlockOutlet>` when the editor
 * is active. Wired via `DEBUG_CALLBACK.OUTLET_INFO_COMPONENT` in the api-initializer.
 *
 * The host BlockOutlet curries this component with `{ outletName, blockCount,
 * outletArgs, error }` and renders it; we add a small label badge above the
 * outlet content and yield the children unchanged.
 *
 * When `blockCount === 0`, the `BlockOutletRootContainer` renders nothing, so
 * there's no `<BlockChrome>` to host a drop zone. Render an inline
 * `<EditorEmptyOutletDropZone>` instead so the palette can populate the
 * outlet.
 */
const OutletBoundary = <template>
  <div class="visual-editor-outlet-boundary" data-outlet-name={{@outletName}}>
    <span class="visual-editor-outlet-boundary__badge">
      {{dIcon "cubes"}}
      <span>{{@outletName}}</span>
      {{#if @blockCount}}
        <span class="visual-editor-outlet-boundary__count">·
          {{@blockCount}}</span>
      {{/if}}
    </span>
    {{yield}}
    {{#unless @blockCount}}
      <EditorEmptyOutletDropZone @outletName={{@outletName}} />
    {{/unless}}
  </div>
</template>;

export default OutletBoundary;
