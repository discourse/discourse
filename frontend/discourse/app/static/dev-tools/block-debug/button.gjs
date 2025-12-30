import Component from "@glimmer/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import DMenu from "discourse/float-kit/components/d-menu";
import concatClass from "discourse/helpers/concat-class";
import icon from "discourse/helpers/d-icon";
import devToolsState from "../state";

/**
 * Block debug button with dropdown menu.
 * Provides separate toggles for console logging, visual overlay, and outlet boundaries.
 *
 * @component BlockDebugButton
 */
export default class BlockDebugButton extends Component {
  get isActive() {
    return (
      devToolsState.blockDebug ||
      devToolsState.blockVisualOverlay ||
      devToolsState.blockOutletBoundaries
    );
  }

  @action
  toggleConsoleLogging(event) {
    devToolsState.blockDebug = event.target.checked;
  }

  @action
  toggleVisualOverlay(event) {
    devToolsState.blockVisualOverlay = event.target.checked;
  }

  @action
  toggleOutletBoundaries(event) {
    devToolsState.blockOutletBoundaries = event.target.checked;
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
              checked={{devToolsState.blockDebug}}
              {{on "change" this.toggleConsoleLogging}}
            />
            Console logging
          </label>
          <label>
            <input
              type="checkbox"
              checked={{devToolsState.blockVisualOverlay}}
              {{on "change" this.toggleVisualOverlay}}
            />
            Visual overlay
          </label>
          <label>
            <input
              type="checkbox"
              checked={{devToolsState.blockOutletBoundaries}}
              {{on "change" this.toggleOutletBoundaries}}
            />
            Outlet boundaries
          </label>
        </div>
      </:content>
    </DMenu>
  </template>
}
