// @ts-check
import icon from "discourse/helpers/d-icon";

/**
 * Outlet boundary chrome rendered around each `<BlockOutlet>` when the editor
 * is active. Wired via `DEBUG_CALLBACK.OUTLET_INFO_COMPONENT` in the api-initializer.
 *
 * The host BlockOutlet curries this component with `{ outletName, blockCount,
 * outletArgs, error }` and renders it; we add a small label badge above the
 * outlet content and yield the children unchanged.
 */
const OutletBoundary = <template>
  <div class="visual-editor-outlet-boundary" data-outlet-name={{@outletName}}>
    <span class="visual-editor-outlet-boundary__badge">
      {{icon "cubes"}}
      <span>{{@outletName}}</span>
      {{#if @blockCount}}
        <span class="visual-editor-outlet-boundary__count">·
          {{@blockCount}}</span>
      {{/if}}
    </span>
    {{yield}}
  </div>
</template>;

export default OutletBoundary;
