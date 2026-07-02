// @ts-check
import Component from "@glimmer/component";
import { action } from "@ember/object";
import DButton from "discourse/ui-kit/d-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";

/**
 * Row-action menu for a single outline block row. Mounted on demand via
 * `menu.show(triggerEl, { component: OutlineRowActions, data })` when the user
 * opens a row's kebab, so exactly one menu exists at a time regardless of how
 * many rows the outline renders.
 *
 * FloatKit injects two args:
 *   - `@data` {{ onDuplicate: () => void, onDelete: () => void }} — the mutation
 *     callbacks, already bound to the row's block key by the panel.
 *   - `@close` {() => void} — closes the menu. Called BEFORE each action runs so
 *     the action (delete unmounts the row) never fires against a torn-down menu
 *     portal, mirroring the block toolbar's `invokeFromMenu`.
 */
export default class OutlineRowActions extends Component {
  @action
  duplicate() {
    this.args.close?.();
    this.args.data.onDuplicate?.();
  }

  @action
  remove() {
    this.args.close?.();
    this.args.data.onDelete?.();
  }

  <template>
    <div class="wireframe-outline-row-actions">
      <DDropdownMenu as |dropdown|>
        <dropdown.item>
          <DButton
            class="btn-flat"
            @icon="copy"
            @label="wireframe.outline.action.duplicate"
            @action={{this.duplicate}}
          />
        </dropdown.item>
        <dropdown.item>
          <DButton
            class="btn-flat wireframe-outline__row-action--danger"
            @icon="trash-can"
            @label="wireframe.outline.action.delete"
            @action={{this.remove}}
          />
        </dropdown.item>
      </DDropdownMenu>
    </div>
  </template>
}
