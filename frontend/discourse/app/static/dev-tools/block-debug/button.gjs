import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import blockDebugState from "discourse/lib/blocks/debug-state";

/**
 * Block debug button with dropdown menu.
 * Provides separate toggles for console logging and visual overlay.
 *
 * @component BlockDebugButton
 */
export default class BlockDebugButton extends Component {
  get isActive() {
    return blockDebugState.enabled || blockDebugState.visualOverlay;
  }

  @action
  toggleConsoleLogging(event) {
    blockDebugState.enabled = event.target.checked;
  }

  @action
  toggleVisualOverlay(event) {
    blockDebugState.visualOverlay = event.target.checked;
  }

  <template>
    <DMenu
      @identifier="block-debug-menu"
      @triggerClass={{concatClass
        "toggle-blocks"
        (if this.isActive "--active")
      }}
      @modalForMobile={{false}}
    >
      <:trigger>
        {{icon "cubes"}}
      </:trigger>
      <:content>
        <div class="block-debug-menu">
          <label>
            <input
              type="checkbox"
              checked={{blockDebugState.enabled}}
              {{on "change" this.toggleConsoleLogging}}
            />
            Console logging
          </label>
          <label>
            <input
              type="checkbox"
              checked={{blockDebugState.visualOverlay}}
              {{on "change" this.toggleVisualOverlay}}
            />
            Visual overlay
          </label>
        </div>
      </:content>
    </DMenu>
  </template>
}
