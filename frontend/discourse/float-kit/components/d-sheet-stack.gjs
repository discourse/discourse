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
 * @param {string} componentId - Optional explicit ID for the stack
 */
export default class Root extends Component {
  @service sheetStackRegistry;

  id = this.args.componentId || guidFor(this);

  constructor(owner, args) {
    super(owner, args);

    // Register stack early so children can register
    this.sheetStackRegistry.registerStack({ id: this.id }, null);

    registerDestructor(this, () => {
      this.sheetStackRegistry.unregisterStack(this.id);
    });
  }

  <template>{{yield (hash stackId=this.id)}}</template>
}
