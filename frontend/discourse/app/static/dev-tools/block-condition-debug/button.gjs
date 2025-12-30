import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import devToolsState from "../state";

export default class BlockConditionDebugButton extends Component {
  @action
  toggle() {
    devToolsState.blockConditionDebug = !devToolsState.blockConditionDebug;
  }

  <template>
    <button
      title="Toggle block condition debug"
      class={{concatClass
        "toggle-block-conditions"
        (if devToolsState.blockConditionDebug "--active")
      }}
      {{on "click" this.toggle}}
    >
      {{icon "cubes"}}
    </button>
  </template>
}
