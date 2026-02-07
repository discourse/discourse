import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { hash } from "@ember/helper";
import { guidFor } from "@ember/object/internals";
import { service } from "@ember/service";

/**
 * Root component for sheet stacking.
 * Groups together several Sheets and enables stacking-driven animations.
 *
 * @component DSheetStackRoot
 * @param {string} [componentId] - Optional explicit ID for the stack
 * @yields {{ stackId: string }} Block params with the resolved stack ID
 */
export default class Root extends Component {
  /**
   * @type {import("../services/sheet-stack-registry").default}
   */
  @service sheetStackRegistry;

  /**
   * Resolved stack ID, from args or auto-generated.
   * @type {string}
   */
  id = this.args.componentId || guidFor(this);

  /**
   * Registers the stack in the registry and sets up a destructor to unregister it.
   * @param {unknown} owner - Ember owner instance
   * @param {Object} args - Component arguments
   */
  constructor(owner, args) {
    super(owner, args);

    // Register stack early so children can register
    this.sheetStackRegistry.registerStack({ id: this.id });

    registerDestructor(this, () => {
      this.sheetStackRegistry.unregisterStack(this.id);
    });
  }

  <template>{{yield (hash stackId=this.id)}}</template>
}
