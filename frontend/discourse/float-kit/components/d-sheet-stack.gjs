import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { hash } from "@ember/helper";
import { guidFor } from "@ember/object/internals";
import { service } from "@ember/service";
import mergeSheetStackAttributes from "../modifiers/merge-sheet-stack-attributes";
import StackOutlet from "./d-sheet-stack-outlet";

export default class Root extends Component {
  @service sheetStackRegistry;

  id = this.args.componentId || guidFor(this);

  constructor(owner, args) {
    super(owner, args);

    this.sheetStackRegistry.registerStack({ id: this.id });

    registerDestructor(this, () => {
      this.sheetStackRegistry.unregisterStack(this.id);
    });
  }

  <template>
    <div ...attributes {{mergeSheetStackAttributes "root"}}>
      {{yield
        (hash stackId=this.id Outlet=(component StackOutlet stackId=this.id))
      }}
    </div>
  </template>
}
