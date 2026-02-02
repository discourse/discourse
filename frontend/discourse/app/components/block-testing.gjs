import Component from "@glimmer/component";
import {
  getInternalComponentManager,
  setInternalComponentManager,
} from "@glimmer/manager";

const defaultGlimmerComponentManager = getInternalComponentManager(Component);

export const BLOCK_SYMBOL = Symbol("block");

const BlockComponentManager = new Proxy(defaultGlimmerComponentManager, {
  get(target, prop) {
    if (prop === "create") {
      return function (owner, klass, args) {
        if (args.named.get("_block")?.compute() !== BLOCK_SYMBOL) {
          throw new Error("Blocks can only be used in block context");
        }
        return target.create(...arguments);
      };
    }
    return Reflect.get(target, prop);
  },
});

function block(target) {
  setInternalComponentManager(BlockComponentManager, target);
  return target;
}

@block
export default class MyBlock extends Component {
  <template>Hello world abcdefg</template>
}
