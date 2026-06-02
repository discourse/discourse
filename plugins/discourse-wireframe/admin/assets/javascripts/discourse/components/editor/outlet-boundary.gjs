// @ts-check
import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";

/**
 * Outlet boundary chrome rendered around each `<BlockOutlet>` when the
 * editor is active. Wired via `DEBUG_CALLBACK.OUTLET_INFO_COMPONENT` in
 * the api-initializer.
 *
 * The host BlockOutlet curries this component with `{ outletName,
 * blockCount, outletArgs, error }` and renders it; we add a label badge
 * above the outlet content and yield the children unchanged.
 *
 * The outlet is an implicit layout: its content is normalised to a single
 * root `layout` block, and the badge selects it (`selectOutlet`) so the
 * inspector surfaces the layout form (mode / gap / grid). Drops and the
 * empty-state placeholder are owned by that root layout's own chrome, so
 * the boundary itself is no longer a drop target — dropping a sibling at
 * the outlet level would break the single-root invariant.
 */
export default class OutletBoundary extends Component {
  @service wireframe;

  /**
   * `true` when this outlet's implicit root layout is the current
   * selection — drives the badge's active styling.
   *
   * @returns {boolean}
   */
  get isSelected() {
    const key = this.wireframe.outletRootKey(this.args.outletName);
    return key != null && this.wireframe.isBlockSelected(key);
  }

  @action
  select() {
    this.wireframe.selectOutlet(this.args.outletName);
  }

  <template>
    <div class="wireframe-outlet-boundary" data-outlet-name={{@outletName}}>
      <button
        type="button"
        class={{dConcatClass
          "wireframe-outlet-boundary__badge"
          (if this.isSelected "--active")
        }}
        aria-pressed={{this.isSelected}}
        {{on "click" this.select}}
      >
        {{dIcon "cubes"}}
        <span>{{@outletName}}</span>
      </button>
      {{yield}}
    </div>
  </template>
}
