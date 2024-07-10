import EmberObject from "@ember/object";
import PluginOutlet from "discourse/components/plugin-outlet";
import { connectorsExist } from "discourse/lib/plugin-connectors";
import rawRenderGlimmer from "discourse/lib/raw-render-glimmer";

export default class extends EmberObject {
  get shouldRender() {
    return connectorsExist(this.name);
  }

  get html() {
    return rawRenderGlimmer(
      this,
      this.tagName || "span",
      <template>
        {{~! no whitespace ~}}
        <PluginOutlet @name={{@data.name}} @outletArgs={{@data.outletArgs}} />
        {{~! no whitespace ~}}
      </template>,
      { name: this.name, outletArgs: this.outletArgs }
    );
  }
}
