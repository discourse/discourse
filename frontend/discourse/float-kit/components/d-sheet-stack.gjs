import Component from "@glimmer/component";
import { registerDestructor } from "@ember/destroyable";
import { hash } from "@ember/helper";
import { guidFor } from "@ember/object/internals";
import { service } from "@ember/service";

export default class Root extends Component {
  @service sheetStackRegistry;

  id = this.args.componentId || guidFor(this);

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
